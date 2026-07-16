# Streaming & Testing

Two things the async client makes easy: consuming a response incrementally, and testing the whole stack offline.

## Streaming responses

`URLSession.bytes(for:)` returns an `AsyncSequence` you can iterate as data arrives — no waiting for the full body, no polling.

```swift
let (bytes, response) = try await session.bytes(for: request)
guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw APIError.server(status: -1) }

for try await line in bytes.lines {          // .lines convenience; also .characters, or raw UInt8
    handle(line)
    try Task.checkCancellation()
}
```

### Server-Sent Events (SSE)

Many "streaming" APIs (including LLM endpoints) use `text/event-stream`. Parse the `data:` lines off the byte stream:

```swift
func events(for request: URLRequest) -> AsyncThrowingStream<ServerEvent, Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                let (bytes, response) = try await session.bytes(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.server(status: -1) }
                for try await line in bytes.lines {
                    guard line.hasPrefix("data:") else { continue }
                    let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    if payload == "[DONE]" { break }
                    continuation.yield(try JSONDecoder.api.decode(ServerEvent.self, from: Data(payload.utf8)))
                }
                continuation.finish()
            } catch { continuation.finish(throwing: error) }
        }
        continuation.onTermination = { _ in task.cancel() }    // cancel the stream when the consumer stops
    }
}
```

Consume with `for try await event in client.events(for: request)`. `onTermination` ties stream teardown to the network task so leaving the screen cancels it.

> For LLM/Foundation Models streaming specifically, prefer the `foundation-models` skill's streaming APIs; use raw SSE only for third-party HTTP streaming endpoints.

## Testing with a mocked `URLProtocol`

Never test against the live API (Common Mistake #8). Register a `URLProtocol` subclass that returns canned responses, and inject it via the session configuration — the entire real code path (request building, status validation, decoding) runs, only the wire is stubbed.

```swift
final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { fatalError("set MockURLProtocol.handler") }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

func makeTestClient() -> APIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return APIClient(baseURL: URL(string: "https://api.test")!, session: URLSession(configuration: config))
}
```

```swift
import Testing

@Test func decodesTrips() async throws {
    MockURLProtocol.handler = { request in
        let json = #"[{"id":"…","name":"Iceland"}]"#
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (resp, Data(json.utf8))
    }
    let client = makeTestClient()
    let trips = try await client.send(.trips(since: .distantPast))
    #expect(trips.first?.name == "Iceland")
}

@Test func maps404ToClientError() async throws {
    MockURLProtocol.handler = { request in
        let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
        return (resp, Data(#"{"message":"not found"}"#.utf8))
    }
    await #expect(throws: APIError.self) { _ = try await makeTestClient().send(.trips(since: .now)) }
}
```

### What to test

- **Happy-path decode** for each endpoint (catches model/JSON drift).
- **Status mapping:** 401 → `unauthorized`, 4xx → `client(message:)`, 5xx → `server`.
- **Retry logic:** have the handler fail N times then succeed; assert attempt count and that non-idempotent calls don't retry.
- **Token refresh single-flight:** fire concurrent requests that 401; assert exactly one refresh ran.

## Alternative: protocol-abstract the client

Instead of (or with) `URLProtocol`, hide the network behind `protocol HTTPClient` (rest-codable.md) and inject a stub conforming type in tests/previews. `URLProtocol` exercises more of the real stack; a protocol stub is simpler for view-model tests. Use whichever fits the layer under test.

## Pitfalls

- **Not cancelling streams** → the network task outlives the consumer; wire `onTermination`/task cancellation.
- **`URLProtocol` state leaking between tests** → reset `handler` per test (or use per-instance injection) to keep them independent and parallel-safe.
- **Testing only the happy path** → status/retry/refresh bugs ship. Cover the error and concurrency paths explicitly.
