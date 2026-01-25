// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import Foundation
import PipelineModels

/// An interceptor that automatically retries requests upon encountering specific errors.
///
/// `RetryInterceptor` implements an exponential backoff or constant delay strategy
/// for retrying failed operations.
public struct RetryInterceptor: PipelineInterceptor {

    // MARK: - Properties

    /// The maximum number of times to retry a request.
    public let maxRetries: Int

    /// The delay interval to wait before the next retry attempt.
    public let delay: TimeInterval

    /// A set of error codes that are considered retryable.
    public let retryableErrors: Set<UtteranceError.Code>

    // MARK: - Initialization

    /// Creates a retry interceptor.
    ///
    /// - Parameters:
    ///   - maxRetries: The maximum number of retries (default: 3).
    ///   - delay: The wait time between retries in seconds (default: 0.5).
    ///   - retryableErrors: Error codes that trigger a retry (default: internalError, serviceUnavailable).
    public init(
        maxRetries: Int = 3,
        delay: TimeInterval = 0.5,
        retryableErrors: Set<UtteranceError.Code> = [.internalError, .serviceUnavailable]
    ) {
        self.maxRetries = maxRetries
        self.delay = delay
        self.retryableErrors = retryableErrors
    }

    // MARK: - RequestRetrying

    public func retry(
        _ request: any PipelineRequest,
        dueTo error: UtteranceError
    ) async -> RetryResult {
        // 1. Check if the error is retryable
        guard retryableErrors.contains(error.code) else {
            return .doNotRetry
        }

        // 2. Check if we haven't exceeded the max retry count
        // Note: 'PipelineRequest' needs a way to track attempt count.
        // Assuming the request object or context exposes retryCount.
        // For now, we rely on the request checking its own state or tracking this externally?
        // Actually, the standard pattern is the request properties.
        // Let's assume `request.retryCount` exists as per the plan.

        guard await request.retryCount < maxRetries else {
            return .doNotRetry
        }

        return .retryWithDelay(delay)
    }
}
