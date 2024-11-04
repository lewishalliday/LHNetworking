//
//  NetworkManager+Get.swift
//  LHNetworking
//
//  Created by Lewis Halliday on 2024-11-04.
//

import Foundation

extension NetworkManager {
    public func get<T: Decodable>(
        endPoint: String,
        queryParams: [String: String]? = nil,
        headers: [String: String]? = nil,
        debugMode: Bool = false
    ) async throws -> T {
        try await performRequest(
            method: .get,
            endPoint: endPoint,
            queryParams: queryParams,
            headers: headers,
            debugMode: debugMode
        )
    }
}
