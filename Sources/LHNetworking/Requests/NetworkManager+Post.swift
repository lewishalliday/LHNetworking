//
//  NetworkManager+Post.swift
//  LHNetworking
//
//  Created by Lewis Halliday on 2024-11-04.
//

import Foundation

extension NetworkManager {
    public func post<T: Decodable, U: Encodable>(
        endPoint: String,
        body: U,
        headers: [String: String]? = nil,
        debugMode: Bool = false
    ) async throws -> T {
        let encodedBody = try JSONEncoder().encode(body)
        return try await performRequest(
            method: .post,
            endPoint: endPoint,
            body: encodedBody,
            headers: headers,
            debugMode: debugMode
        )
    }
}
