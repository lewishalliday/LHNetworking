# LHNetworking

A tiny, portable, memory‑efficient async/await HTTP client for Swift. Built on URLSession with zero dependencies, pluggable authentication, retries with exponential backoff, structured endpoints, and a strong test story.

- Async/await API that back‑deploys to iOS 13+
- Super portable: iOS, macOS, tvOS, watchOS, visionOS, Linux
- Minimal allocations and copies; streaming‑friendly design
- Pluggable auth (Basic, Bearer, API key; optional HMAC with CryptoKit)
- Configurable retries with exponential backoff and jitter
- Strongly typed `Endpoint` decoding and raw response access
- Easy unit testing via URLProtocol stubs

## Install

Add to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/lewishalliday/LHNetworking.git", from: "0.1.0")
```

Then add `LHNetworking` to your target dependencies.

## Quick Start

```swift
import LHNetworking

struct User: Decodable { let id: Int; let name: String }

let client = URLSessionHTTPClient(
    configuration: .init(
        baseURL: URL(string: "https://api.example.com")!,
        authenticator: BearerTokenAuthenticator(token: "<token>")
    )
)

let user = try await client.send(.json(method: .get, path: "/users/1") as Endpoint<User>)
```

For a full walkthrough, see `USAGE.md`.

## Endpoints

`Endpoint<Response>` describes an HTTP call and provides a parser for the response. Helpers exist for `Void`, `Data`, and `Decodable`.

## Authentication

Use `BasicAuthenticator`, `BearerTokenAuthenticator`, `APIKeyHeaderAuthenticator`, `APIKeyQueryAuthenticator`, or compose your own via `RequestAuthenticator`.

## Retries

Configure `RetryPolicy` with status codes, URL error codes, and backoff. A `Sleeper` hook makes behavior fully testable.

## Testing

Use a `URLSession` configured with a custom `URLProtocol` (e.g. `MockURLProtocol`) to stub responses deterministically.

## Design Notes

- Uses async/await with custom bridging to `URLSession.dataTask` for iOS 13+ and Linux compatibility.
- Avoids unnecessary data copies, enforces small surface area.
- Zero dependencies by default; optional `CryptoKit` for HMAC.

## License

MIT (add your preferred license here).
