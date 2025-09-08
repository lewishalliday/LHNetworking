# Usage

This guide shows common tasks with ``LHNetworking``.

## Define an Endpoint

```swift
struct Repo: Decodable { let name: String }
let repo = Endpoint<Repo>.json(method: .get, path: "/repos/42")
```

## Send Requests

```swift
let client = URLSessionHTTPClient(configuration: .init(baseURL: URL(string: "https://api.example.com")!))
let model = try await client.send(repo)
```

## Raw Responses

```swift
var request = URLRequest(url: URL(string: "https://example.com/raw")!)
request.httpMethod = "GET"
let response = try await client.send(request)
print(response.statusCode)
```

## Authentication

```swift
let basic = URLSessionHTTPClient(configuration: .init(authenticator: BasicAuthenticator(username: "u", password: "p")))
let bearer = URLSessionHTTPClient(configuration: .init(authenticator: BearerTokenAuthenticator(token: "t")))
let apiKey = URLSessionHTTPClient(configuration: .init(authenticator: APIKeyHeaderAuthenticator(header: "X-API-Key", value: "k")))
```

## Retries

```swift
let client = URLSessionHTTPClient(configuration: .init(retryPolicy: RetryPolicy(maxRetries: 3)))
```

