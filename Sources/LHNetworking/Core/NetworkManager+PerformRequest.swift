//
//  NetworkManager+PerformRequest.swift
//  LHNetworking
//
//  Created by Lewis Halliday on 2024-11-04.
//

// Core/NetworkManager+PerformRequest.swift
import Foundation

extension NetworkManager {
    internal func performRequest<T: Decodable>(
        method: HTTPMethod,
        endPoint: String,
        queryParams: [String: String]? = nil,
        body: Data? = nil,
        headers: [String: String]? = nil,
        debugMode: Bool = false
    ) async throws -> T {
        // Construct URL with query parameters
        guard var urlComponents = URLComponents(string: "\(baseURL)\(endPoint)") else {
            throw DefaultNetworkError.invalidURL
        }
        
        if let queryParams = queryParams {
            urlComponents.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = urlComponents.url else {
            throw DefaultNetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Set the Authorization header if a token is provided
        if let token = try await getToken?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        if method == .post || method == .put {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        if debugMode {
            print("🛎️ Request URL: \(request.url?.absoluteString ?? "None")")
            print("🛎️ Request Method: \(method.rawValue)")
            if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                print("🛎️ Request Body: \(bodyString)")
            }
        }
        
        // Execute the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw DefaultNetworkError.requestFailed(statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}
