//
//  NetworkManager+Put.swift
//  LHNetworking
//
//  Created by Lewis Halliday on 2024-11-04.
//

import Foundation

extension NetworkManager {
    public func put<T: Decodable, U: Encodable>(
        endPoint: String,
        body: U,
        headers: [String: String]? = nil,
        debugMode: Bool = false
    ) async throws -> T {
        let encodedBody = try JSONEncoder().encode(body)
        return try await performRequest(
            method: .put,
            endPoint: endPoint,
            body: encodedBody,
            headers: headers,
            debugMode: debugMode
        )
    }
}
