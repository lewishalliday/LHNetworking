//
//  NetworkManager.swift
//  LHNetworking
//
//  Created by Lewis Halliday on 2024-11-04.
//

import Foundation

public struct NetworkManager {
    let baseURL: String
    let getToken: (() async throws -> String?)? // Closure to fetch auth token, if needed

    public init(baseURL: String, getToken: (() async throws -> String?)? = nil) {
        self.baseURL = baseURL
        self.getToken = getToken
    }
}
