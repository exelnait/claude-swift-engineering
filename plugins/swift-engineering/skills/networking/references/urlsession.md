# URLSession

The async `URLSession` API is the whole HTTP surface most apps need. Reuse one session, build requests with `URLComponents`, and let structured concurrency handle cancellation.

## Requests with async/await

```swift
let (data, response) = try await session.data(for: request)     // from a URLRequest
let (data, response) = try await session.data(from: url)        // simple GET
```

- `data(for:)` throws only on **transport** errors (offline, timeout, TLS). An HTTP 404/500 returns normally with a body — you must check the status (see rest-codable.md). This is Common Mistake #1.
- Uploads and downloads:
  ```swift
  let (data, resp)  = try await session.upload(for: request, from: bodyData)   // or fromFile:
  let (fileURL, r)  = try await session.download(for: request)                 // to a temp file
  ```

## Building the request

Use `URLComponents` so query values are percent-encoded correctly (Common Mistake #2):

```swift
var components = URLComponents(string: "https://api.example.com/v1/trips")!
components.queryItems = [
    URLQueryItem(name: "since", value: isoDate),
    URLQueryItem(name: "limit", value: "50"),
]
var request = URLRequest(url: components.url!)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue("application/json", forHTTPHeaderField: "Accept")
request.httpBody = try JSONEncoder().encode(payload)
request.timeoutInterval = 30
```

- Set headers with `setValue(_:forHTTPHeaderField:)` (replaces) or `addValue` (appends).
- Don't hand-encode query strings; let `URLComponents` and `URLQueryItem` do it.

## Configuration — reuse one session

Create a configured session once and share it (Common Mistake #3):

```swift
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 30          // per-request inactivity timeout
config.timeoutIntervalForResource = 300        // whole-transfer deadline
config.waitsForConnectivity = true             // wait for a path instead of failing offline
config.httpAdditionalHeaders = ["User-Agent": userAgent]
config.requestCachePolicy = .useProtocolCachePolicy
config.httpMaximumConnectionsPerHost = 6
let session = URLSession(configuration: config)
```

- **`waitsForConnectivity`** — instead of erroring immediately when offline, the task waits for a usable path (great on mobile). Combine with `timeoutIntervalForResource` as an upper bound.
- **`.ephemeral`** config for no-persistence (private) sessions; **`.background(withIdentifier:)`** for transfers that continue after the app is suspended (see below).
- Configuration is read at session creation — change it by making a new session, not by mutating live.

## Cancellation

The async APIs are cancellation-aware: when the surrounding `Task` is cancelled, the request is cancelled and `data(for:)` throws `CancellationError`/`URLError(.cancelled)`. Drive requests from `.task {}` so leaving a screen cancels in flight (Common Mistake #6):

```swift
.task {
    do { model.trips = try await client.trips() }
    catch is CancellationError { /* expected on disappear */ }
    catch { model.error = error }
}
```

Around manual retry loops, check `try Task.checkCancellation()` so a cancelled task stops retrying.

## Background sessions (out-of-process transfers)

For large uploads/downloads that must survive app suspension/termination, use a background configuration + delegate (the async convenience methods don't apply):

```swift
let config = URLSessionConfiguration.background(withIdentifier: "com.example.bg")
config.isDiscretionary = false
config.sessionSendsLaunchEvents = true
let session = URLSession(configuration: config, delegate: BGDelegate(), delegateQueue: nil)
session.downloadTask(with: request).resume()
// Implement urlSession(_:downloadTask:didFinishDownloadingTo:) and handle the app relaunch event.
```

Reserve this for genuine background transfers; ordinary API calls use a default session.

## Redirects, cookies, auth challenges

- Default behavior follows redirects and stores cookies (`HTTPCookieStorage`). Customize via a `URLSessionTaskDelegate` (`urlSession(_:task:willPerformHTTPRedirection:)`, `didReceive challenge:`) — the async methods accept a per-task `delegate:` parameter.
- For server-trust / client-cert challenges, implement `urlSession(_:didReceive:completionHandler:)`. Never disable trust evaluation in shipping code.

## Pitfalls

- **One session per request** → wasted connections; reuse.
- **Mutating a config after session creation** → no effect; recreate the session.
- **Treating any thrown error as "no network"** → distinguish `URLError` codes (`.cancelled`, `.timedOut`, `.notConnectedToInternet`) for correct UX.
