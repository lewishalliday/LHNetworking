# ``LHNetworking``

Build reliable, portable, memory‑efficient HTTP clients with async/await. ``LHNetworking`` wraps `URLSession` with a tiny, testable core, pluggable authentication, retries with backoff, structured endpoints, and strong defaults.

## Highlights

- Async/await API that back‑deploys to iOS 13+
- Zero dependencies; lightweight over `URLSession`
- Pluggable auth (Basic, Bearer, API key, optional HMAC)
- Exponential backoff with jitter; configurable retries
- Strongly typed `Endpoint` decoding and raw access
- Loggable, composable, highly testable (URLProtocol stubs)

## Quick Start

```swift
import LHNetworking

struct User: Decodable { let id: Int; let name: String }

let base = URL(string: "https://api.example.com")!
let client = URLSessionHTTPClient(
    configuration: .init(
        baseURL: base,
        authenticator: BearerTokenAuthenticator(token: "<token>")
    )
)

let endpoint = Endpoint<User>.json(method: .get, path: "/users/1")
let user = try await client.send(endpoint)
```

## Testing

Inject a session configured with a custom `URLProtocol` to deterministically stub requests and assert behavior.

