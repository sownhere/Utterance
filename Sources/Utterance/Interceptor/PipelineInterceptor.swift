// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import AVFoundation
import Foundation
import PipelineModels

// MARK: - Audio Adapting

/// Adapts audio buffers before they are processed by the pipeline.
///
/// Use `AudioAdapting` to implement features like:
/// - Noise reduction or normalization
/// - Resampling or format conversion
/// - Audio analysis or metering
/// - Watermarking
public protocol AudioAdapting: Sendable {
    /// Adapt the audio buffer for the given request.
    ///
    /// - Parameters:
    ///   - buffer: The original audio buffer captured by the recorder.
    ///   - request: The pipeline request triggering this adaptation.
    /// - Returns: The modified audio buffer.
    func adapt(
        _ buffer: AVAudioPCMBuffer,
        for request: any PipelineRequest
    ) async throws -> AVAudioPCMBuffer
}

// MARK: - Request Retrying

/// Outcome of a retry decision.
public enum RetryResult: Sendable {
    /// Retry the request immediately.
    case retry
    /// Retry the request after a specified delay.
    case retryWithDelay(TimeInterval)
    /// Do not retry the request; propagate the error.
    case doNotRetry
}

/// Determines whether a failed request should be retried.
///
/// Use `RequestRetrying` to handle resilient interactions, such as:
/// - Retrying on network timeouts or transient server errors.
/// - Attempting to re-initialize audio engines on hardware failure.
public protocol RequestRetrying: Sendable {
    /// Determine if the request should be retried after an error.
    ///
    /// - Parameters:
    ///   - request: The pipeline request that failed.
    ///   - error: The error that caused the failure.
    /// - Returns: A `RetryResult` indicating the retry strategy.
    func retry(
        _ request: any PipelineRequest,
        dueTo error: UtteranceError
    ) async -> RetryResult
}

// MARK: - Pipeline Interceptor

/// A type that can inspect, modify, and retry pipeline requests.
///
/// `PipelineInterceptor` combines `AudioAdapting` and `RequestRetrying` capabilities.
/// You can implement one or both of these protocols. Default implementations are provided
/// that perform no-op (pass-through) operations.
public protocol PipelineInterceptor: AudioAdapting, RequestRetrying, Sendable {}

// MARK: - Default Implementations

extension PipelineInterceptor {
    public func adapt(
        _ buffer: AVAudioPCMBuffer,
        for request: any PipelineRequest
    ) async throws -> AVAudioPCMBuffer {
        return buffer
    }

    public func retry(
        _ request: any PipelineRequest,
        dueTo error: UtteranceError
    ) async -> RetryResult {
        return .doNotRetry
    }
}
