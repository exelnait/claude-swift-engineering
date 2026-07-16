# Resilience & Auth

Real APIs drop connections, rate-limit, and expire tokens. Handle these once in the client layer so features don't each reinvent (badly) retry and auth.

## Retries with backoff + jitter

Retry only **idempotent** requests (GET/PUT/DELETE, or POSTs with an idempotency key), only on **retryable** conditions, with a **cap** and **exponential backoff + jitter** (Common Mistake #4):

```swift
func withRetry<T>(maxAttempts: Int = 3, isIdempotent: Bool, _ operation: () async throws -> T) async throws -> T {
    var attempt = 0
    while true {
        do { return try await operation() }
        catch {
            attempt += 1
            try Task.checkCancellation()                    // stop retrying if cancelled
            guard isIdempotent, attempt < maxAttempts, isRetryable(error) else { throw error }
            let base = pow(2.0, Double(attempt))            // 2, 4, 8 …
            let jitter = Double.random(in: 0...0.5)         // spread the herd
            try await Task.sleep(for: .seconds(base + jitter))
        }
    }
}

func isRetryable(_ error: Error) -> Bool {
    switch error {
    case APIError.server: return true                        // 5xx
    case let urlError as URLError:
        return [.timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet].contains(urlError.code)
    default: return false                                     // 4xx (except 429) are not retryable
    }
}
```

- **Never retry non-idempotent writes** without an idempotency key, or you double-charge/double-post.
- **`429 Too Many Requests`:** honor the `Retry-After` header instead of your own backoff when present.
- Keep `maxAttempts` small; retries are for transient blips, not a broken server.

## Timeouts & connectivity

- Per-request inactivity: `URLSessionConfiguration.timeoutIntervalForRequest`; whole-transfer deadline: `timeoutIntervalForResource` (see urlsession.md).
- `waitsForConnectivity = true` waits for a usable path rather than failing offline — pair it with a resource timeout so it can't wait forever.
- Distinguish `URLError` codes for UX: `.notConnectedToInternet` (show offline), `.timedOut` (retry), `.cancelled` (ignore).

## Request adapters / interceptors

A small adapter protocol lets you inject cross-cutting behavior (auth headers, tracing ids) without touching every call:

```swift
protocol RequestAdapter: Sendable {
    func adapt(_ request: URLRequest) async throws -> URLRequest
}

struct AuthAdapter: RequestAdapter {
    let tokenProvider: TokenProvider
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var r = request
        r.setValue("Bearer \(try await tokenProvider.validAccessToken())", forHTTPHeaderField: "Authorization")
        return r
    }
}
```

The client runs its adapters before sending (see rest-codable.md). Add a logging/tracing adapter the same way.

## Bearer auth + single-flight token refresh

The classic bug: several requests 401 at once and each starts a refresh, racing and invalidating tokens (Common Mistake #5). Serialize refresh with an actor so only one runs and the rest await it:

```swift
actor TokenProvider {
    private var accessToken: Token?
    private var refreshTask: Task<Token, Error>?
    let refresh: @Sendable (Token) async throws -> Token

    func validAccessToken() async throws -> String {
        if let t = accessToken, !t.isExpired { return t.value }
        return try await refreshToken().value
    }

    func refreshToken() async throws -> Token {
        if let task = refreshTask { return try await task.value }   // join the in-flight refresh
        let task = Task { [current = accessToken] in
            defer { refreshTask = nil }
            let new = try await refresh(current ?? .empty)
            accessToken = new
            return new
        }
        refreshTask = task
        return try await task.value
    }
}
```

On a `401` from a call, `await tokenProvider.refreshToken()` then retry the request **once**; if it 401s again, surface `unauthorized` (sign the user out). Because refresh is single-flight, ten concurrent 401s trigger exactly one refresh.

## Rate limiting

- Respect `429` + `Retry-After`. Optionally add a client-side limiter (an actor gating concurrent requests / spacing them) for APIs with strict quotas.
- Back off globally on repeated `429`/`503` rather than hammering.

## Pitfalls

- **Retrying POSTs blindly** → duplicate side effects; require idempotency.
- **No jitter** → synchronized retry storms after an outage.
- **Concurrent refreshes** → token thrash; serialize with an actor.
- **Retrying 4xx** (except 429) → wasted calls; those are client errors, fix the request.
- **Ignoring `Retry-After`** → you fight the server's stated backoff.
