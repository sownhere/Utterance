// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import Foundation

// MARK: - Request State

/// Request lifecycle states following Alamofire's pattern.
///
/// States flow typically: `initialized` → `running` → `finished`
/// With optional suspension: `running` ↔ `suspended`
public enum RequestState: String, Sendable, Equatable {

    /// Request has been created but not started
    case initialized

    /// Request is actively processing
    case running

    /// Request is paused, can be resumed
    case suspended

    /// Cancellation has been requested
    case cancelling

    /// Request has completed (success or failure)
    case finished
}

// MARK: - Request Event

/// Container for request state changes with timestamp
public struct RequestEvent: Sendable {
    public let state: RequestState
    public let timestamp: Date
    public let metadata: [String: String]

    public init(
        state: RequestState,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.state = state
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Request ID

/// Unique identifier for requests
public struct RequestID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init() {
        self.rawValue = UUID()
    }

    public var description: String {
        rawValue.uuidString.prefix(8).lowercased()
    }
}
