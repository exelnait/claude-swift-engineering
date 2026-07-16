# REST & Codable

Turn the raw `(Data, URLResponse)` into typed models and a small reusable client. The goal: one place that knows how to send an endpoint, validate the status, and decode — so call sites are one line.

## Configure the coders once

```swift
extension JSONDecoder {
    static let api: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase     // server snake_case → Swift camelCase
        d.dateDecodingStrategy = .iso8601                 // or a custom formatter
        return d
    }()
}
extension JSONEncoder {
    static let api: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
```

Set these once (Common Mistake #7). For odd date formats use `.formatted(_:)` or `.custom { }`; for keys that don't fit a strategy, provide explicit `CodingKeys`.

## Model the endpoint as a value

```swift
struct Endpoint<Response: Decodable> {
    var path: String
    var method: String = "GET"
    var query: [URLQueryItem] = []
    var body: Data? = nil
    var headers: [String: String] = [:]
}

extension Endpoint {
    static func trips(since: Date) -> Endpoint<[Trip]> {
        Endpoint(path: "/v1/trips", query: [URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: since))])
    }
    static func createTrip(_ input: TripInput) throws -> Endpoint<Trip> {
        Endpoint(path: "/v1/trips", method: "POST", body: try JSONEncoder.api.encode(input),
                 headers: ["Content-Type": "application/json"])
    }
}
```

The generic `Response` ties each endpoint to what it decodes into, so the client returns the right type with no casting.

## The client

```swift
protocol HTTPClient: Sendable {
    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response
}

struct APIClient: HTTPClient {
    let baseURL: URL
    let session: URLSession
    var adapters: [any RequestAdapter] = []          // auth etc. — see resilience.md

    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        var request = try makeRequest(endpoint)
        for adapter in adapters { request = try await adapter.adapt(request) }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.nonHTTPResponse }
        try validate(http, data: data)                // maps non-2xx to APIError

        if Response.self == Empty.self { return Empty() as! Response }   // 204 / no body
        return try JSONDecoder.api.decode(Response.self, from: data)
    }

    private func makeRequest<R>(_ e: Endpoint<R>) throws -> URLRequest {
        var comps = URLComponents(url: baseURL.appending(path: e.path), resolvingAgainstBaseURL: false)!
        if !e.query.isEmpty { comps.queryItems = e.query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = e.method
        req.httpBody = e.body
        e.headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        return req
    }
}
struct Empty: Decodable {}
```

Call sites become trivial and typed:

```swift
let trips = try await client.send(.trips(since: lastSync))       // [Trip]
let created = try await client.send(try .createTrip(input))      // Trip
```

## Status → typed error

Never treat a returned body as success without checking the code (Common Mistake #1):

```swift
enum APIError: Error {
    case nonHTTPResponse
    case unauthorized                       // 401 — triggers refresh (resilience.md)
    case client(status: Int, message: String?)   // 4xx
    case server(status: Int)                // 5xx — often retryable
    case decoding(any Error)
}

func validate(_ http: HTTPURLResponse, data: Data) throws {
    switch http.statusCode {
    case 200...299: return
    case 401:       throw APIError.unauthorized
    case 400...499:
        let message = try? JSONDecoder.api.decode(ServerError.self, from: data).message
        throw APIError.client(status: http.statusCode, message: message)
    case 500...599: throw APIError.server(status: http.statusCode)
    default:        throw APIError.client(status: http.statusCode, message: nil)
    }
}
struct ServerError: Decodable { let message: String }
```

Decoding the server's error envelope on 4xx gives you a real message to surface instead of a generic failure.

## Decoding tips

- **Wrap decode errors** (`catch { throw APIError.decoding($0) }`) so you can log the mismatch (`DecodingError` says exactly which key/type failed).
- **Optional/loose fields:** make truly-optional JSON fields `Optional`; provide defaults in a custom `init(from:)` when the server omits keys.
- **Enums from strings:** back API enums with a default/unknown case so a new server value doesn't crash decoding.
- **Nested/enveloped payloads** (`{ "data": {...} }`): decode a thin `Envelope<T>` and unwrap, rather than leaking the envelope into every model.

## Pitfalls

- **Skipping status validation** → decode an error page as your model.
- **Per-call decoders with default strategies** → snake_case/date mismatches; share one configured decoder.
- **Crashing on unknown enum values** → use an unknown case.
- **Leaking transport types into the domain** → keep `URLRequest`/`HTTPURLResponse` inside the client; hand features typed models and `APIError`.
