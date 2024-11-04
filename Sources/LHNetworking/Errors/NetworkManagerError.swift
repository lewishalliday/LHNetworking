//
//  NetworkManagerError.swift
//  LHNetworking
//
//  Created by Lewis Halliday on 2024-11-04.
//

import Foundation

public protocol NetworkManagerError: Error {
    var message: String { get }
}

public enum DefaultNetworkError: NetworkManagerError {
    case invalidURL
    case requestFailed(Int)
    case missingData
    case apiErrorResponse(String)

    public var message: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .requestFailed(let code): return "Request failed with status code: \(code)"
        case .missingData: return "Data missing in response"
        case .apiErrorResponse(let error): return "API Error: \(error)"
        }
    }
}
