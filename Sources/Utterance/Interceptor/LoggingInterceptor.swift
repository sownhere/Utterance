// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import AVFoundation
import Foundation
import PipelineModels

/// An interceptor that logs pipeline events and audio adaptability.
public struct LoggingInterceptor: PipelineInterceptor {

    // MARK: - Types

    /// Logging severity levels.
    public enum Level: Sendable {
        case debug
        case info
        case warning
        case error
    }

    // MARK: - Properties

    private let level: Level
    private let logger: @Sendable (String, Level) -> Void

    // MARK: - Initialization

    /// Creates a logging interceptor.
    ///
    /// - Parameters:
    ///   - level: The minimum log level to capture.
    ///   - logger: A closure to handle the log output (default: print).
    public init(
        level: Level = .info,
        logger: @escaping @Sendable (String, Level) -> Void = { message, level in
            print("[Utterance][\(level)] \(message)")
        }
    ) {
        self.level = level
        self.logger = logger
    }

    // MARK: - AudioAdapting

    public func adapt(
        _ buffer: AVAudioPCMBuffer,
        for request: any PipelineRequest
    ) async throws -> AVAudioPCMBuffer {
        logger(
            "Audio buffer received: frameLength=\(buffer.frameLength), format=\(buffer.format)",
            .debug)
        return buffer
    }

    // MARK: - RequestRetrying

    public func retry(
        _ request: any PipelineRequest,
        dueTo error: UtteranceError
    ) async -> RetryResult {
        logger("Request \(request.id) failed with error: \(error.localizedDescription)", .warning)
        return .doNotRetry  // We observe but don't intervene in retry logic
    }
}
