# LHNetworking

`LHNetworking` is a lightweight and modular Swift package designed to simplify network requests. It provides easy-to-use methods for making `GET`, `POST`, `PUT`, and `DELETE` requests with support for authentication, custom headers, and detailed error handling.

## Features
- **Asynchronous Requests**: Built using Swift’s async/await for efficient, modern network handling.
- **Modular Design**: Cleanly split into separate files, making it easy to customize and extend.
- **Customizable Errors**: Includes default error handling, with support for custom error types.
- **Debugging Support**: Toggle debug mode to print detailed request and response information.

## Requirements
- iOS 13.0+ 
- Swift 5.5+

## Installation

### Swift Package Manager

1. In Xcode, go to **File > Swift Packages > Add Package Dependency**.
2. Enter the repository URL: https://github.com/lewishalliday/LHNetworking
3. Follow the prompts to add the package to your project.

## Usage

### 1. Import LHNetworking

To use `LHNetworking` in your Swift file, import the package:

```swift
import LHNetworking
```

### 2. Initialize NetworkManager

Create an instance of `NetworkManager` by providing a base URL and an optional token retrieval closure for authentication.

#### Example Initialization

```swift
let networkManager = NetworkManager(
    baseURL: "https://api.example.com",
    getToken: {
        // Logic to retrieve authentication token if required
        return "your-auth-token" // Replace with actual token retrieval logic
    }
)
```

- **baseURL**: The base URL for the API.
- **getToken**: An optional asynchronous closure that returns an authentication token. This will automatically set an `Authorization` header for each request.

### 3. Making Requests

`LHNetworking` provides functions for `GET`, `POST`, `PUT`, and `DELETE` requests. Each method is generic and expects a `Decodable` type for the response, making it easy to work with JSON responses directly.

#### GET Request

Use `get` to fetch data. The response type must conform to `Decodable`.

```swift
struct User: Decodable {
    let id: Int
    let name: String
    let email: String
}

func fetchUsers() async {
    do {
        let users: [User] = try await networkManager.get(endPoint: "/users", debugMode: true)
        print("Fetched users:", users)
    } catch {
        print("Failed to fetch users:", error)
    }
}
```

You can also create wrapper functions to simplify usage further:

```swift
func getUsers() async throws -> [User] {
    try await networkManager.get(endPoint: "/users")
}
```

#### POST Request

Use `post` to create data. The request body must conform to `Encodable`.

```swift
struct NewUser: Encodable {
    let name: String
    let email: String
}

func createUser(name: String, email: String) async {
    let newUser = NewUser(name: name, email: email)
    do {
        let createdUser: User = try await networkManager.post(endPoint: "/users", body: newUser, debugMode: true)
        print("Created user:", createdUser)
    } catch {
        print("Failed to create user:", error)
    }
}
```

A simplified wrapper function can also be created for posting users:

```swift
func postUser(_ user: User) async throws -> User {
    try await networkManager.post(endPoint: "/user", body: user)
}
```

#### PUT Request

Use `put` to update data. The request body must conform to `Encodable`.

```swift
struct UpdateUser: Encodable {
    let name: String
    let email: String
}

func updateUser(id: Int, name: String, email: String) async {
    let updatedUser = UpdateUser(name: name, email: email)
    do {
        let response: User = try await networkManager.put(endPoint: "/users/\(id)", body: updatedUser, debugMode: true)
        print("Updated user:", response)
    } catch {
        print("Failed to update user:", error)
    }
}
```

#### DELETE Request

Use `delete` to remove data. No request body is needed for `DELETE` requests.

```swift
func deleteUser(id: Int) async {
    do {
        let response: String = try await networkManager.delete(endPoint: "/users/\(id)", debugMode: true)
        print("Deleted user response:", response)
    } catch {
        print("Failed to delete user:", error)
    }
}
```

### Error Handling

`LHNetworking` includes a customizable error-handling system through the `NetworkManagerError` protocol. By default, it provides `DefaultNetworkError` to handle common issues such as:

- **Invalid URL**: The URL could not be formed.
- **Request Failed**: The request failed with a specific status code.
- **Missing Data**: Expected data was missing in the response.
- **API Error Response**: The API returned an error message.

To handle errors, use `do-catch` blocks around your network calls.

```swift
do {
    let users: [User] = try await networkManager.get(endPoint: "/users")
} catch let error as NetworkManagerError {
    print("Network error occurred:", error.message)
} catch {
    print("An unexpected error occurred:", error)
}
```

### Debugging

Enable `debugMode` in any request to print detailed request and response information.

```swift
let users: [User] = try await networkManager.get(endPoint: "/users", debugMode: true)
```

This mode provides insights into the URL, headers, body, and response data, which is helpful for troubleshooting API interactions.

## Advanced Usage

You can extend `NetworkManager` by creating custom request methods or integrating additional headers, query parameters, or other request configurations. Additionally, you can add custom error handling by implementing `NetworkManagerError`.
