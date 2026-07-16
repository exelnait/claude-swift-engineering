---
name: networking
description: >-
  Use when talking to an HTTP/REST API from Swift — `URLSession` with async/await (`data(for:)`, upload/download), building `URLRequest`s with `URLComponents`, encoding/decoding JSON with `Codable`, a reusable typed `APIClient`/endpoint layer, mapping HTTP status codes to typed errors, retries/backoff, timeouts and connectivity, authentication and token refresh, request adapters/interceptors, streaming responses (`URLSession.bytes`, SSE), and testing with a mocked `URLProtocol`. This is the application-level HTTP skill; for low-level sockets/custom protocols (TCP/UDP, TLS, Bonjour) use `swift-networking` (Network.framework) instead. Load whenever a feature fetches, posts, uploads, downloads, streams, or authenticates against a web service.
---

# Networking (URLSession + async/await)

Most apps' "networking" is HTTP against a JSON API — and modern `URLSession` with `async/await` makes that clean without a third-party stack. This skill is the application layer: typed requests, `Codable` bodies, a small reusable client, and the resilience (retries, auth, cancellation) real APIs demand. For raw sockets, custom wire protocols, TLS, or Bonjour discovery, that's a different tool — see `swift-networking` (Network.framework).

The core principle: **model each endpoint as a value, send it through one small `Sendable` client, decode into `Codable` types, and map failures to typed errors.** No callback pyramids, no `URLSession` scattered across view models — one seam you can test, retry, and authenticate in.

## Quick Reference

| Need | Use | Not |
|------|-----|-----|
| One request | `try await session.data(for: request)` | completion handlers |
| Build a URL | `URLComponents` + `queryItems` | string interpolation |
| JSON body/response | `Codable` + `JSONEncoder`/`JSONDecoder` | manual `JSONSerialization` |
| Decode dates/keys | decoder `.dateDecodingStrategy` / `.keyDecodingStrategy` | hand-rolled parsing |
| HTTP error | inspect `HTTPURLResponse.statusCode` → typed error | assuming 2xx |
| Cancel | structured concurrency / `Task` cancellation | manual flags |
| Survive blips | bounded retry with backoff on idempotent calls | infinite retry |
| Auth | an adapter that injects the token + refreshes on 401 | token copy-pasted per call |
| Stream | `session.bytes(for:)` → `for try await` lines | polling |
| Test | inject a mocked `URLProtocol` | hitting the real network |

## Core Workflow

1. **Define the endpoint** as a value (path, method, query, body) and build a `URLRequest` from it via `URLComponents`.
2. **Send it through one `APIClient`** that owns the `URLSession`, applies adapters (auth headers), and returns `(Data, HTTPURLResponse)`.
3. **Validate the response** — check the status code, map non-2xx to a typed `APIError` (with the decoded server error when present).
4. **Decode** the body into a `Codable` type with configured strategies.
5. **Layer resilience** — timeouts, `waitsForConnectivity`, bounded retry/backoff on idempotent requests, and 401 → refresh-and-retry for auth.
6. **Respect cancellation** — the `async` APIs cancel with the surrounding `Task`; drive requests from `.task`/structured concurrency so leaving a screen cancels in flight.
7. **Test the client** against a mocked `URLProtocol`, never the live API.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** Networking bugs (retry storms, token races, silent 4xx, decoding mismatches) surface in production, not the compiler.

| Reference | Load When |
|-----------|-----------|
| **[URLSession](references/urlsession.md)** | Making requests — async `data`/`upload`/`download`, `URLRequest`/`URLComponents`, `URLSessionConfiguration` (timeouts, headers, caching, `waitsForConnectivity`), background sessions, cancellation |
| **[REST & Codable](references/rest-codable.md)** | Encoding/decoding and structuring the client — `Codable` bodies, `JSONDecoder`/`Encoder` strategies, a generic `Endpoint` + `APIClient`, status-code→typed-error mapping, decoding server error envelopes |
| **[Resilience & Auth](references/resilience.md)** | Making it robust — retries with exponential backoff + jitter, idempotency, timeouts/connectivity, rate-limit handling, bearer-token auth, 401 refresh (single-flight), request adapters/interceptors |
| **[Streaming & Testing](references/streaming-testing.md)** | Streams and tests — `URLSession.bytes` line/byte streaming, server-sent events, and testing the whole stack with a stubbed `URLProtocol` injected via configuration |

## Common Mistakes

1. **Assuming a returned `Data` means success.** `URLSession` only throws on transport failures; an HTTP **4xx/5xx still "succeeds"** with a body. Always cast to `HTTPURLResponse`, check `statusCode`, and map non-2xx to a typed error — otherwise you decode an error page as your model.

2. **Building URLs by string interpolation.** Unescaped query values and path components break silently. Use `URLComponents` with `queryItems` so encoding is correct.

3. **A fresh `URLSession` per request.** Sessions are meant to be reused; creating one per call wastes connections and defeats pooling/caching. Hold one session (or one per host/config) in the client.

4. **Unbounded or immediate retries.** Retrying instantly, forever, or on non-idempotent requests causes retry storms and duplicate writes. Retry only idempotent calls, with a cap and exponential backoff + jitter, and only on retryable conditions (see Resilience & Auth).

5. **Token refresh races.** Multiple concurrent 401s each kick off a refresh, invalidating each other. Serialize refresh (single-flight): the first 401 refreshes, the rest await that result.

6. **Ignoring cancellation.** Fire-and-forget `Task`s keep requests alive after the user leaves. Drive requests from `.task {}`/structured concurrency so navigating away cancels them; check `Task.isCancelled` around retry loops.

7. **Decoding mismatches from unset strategies.** Server `snake_case` keys or ISO-8601 dates fail against default decoding. Configure `keyDecodingStrategy`/`dateDecodingStrategy` once on the shared decoder.

8. **Testing against the real API.** Flaky, slow, and unsafe. Inject a mocked `URLProtocol` (or a protocol-abstracted client) so tests are deterministic and offline.

9. **Reaching for Network.framework for HTTP.** `NWConnection` is for custom protocols/sockets, not REST. For HTTP use `URLSession`; only drop to `swift-networking` when you genuinely need the transport layer.
