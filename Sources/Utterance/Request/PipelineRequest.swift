// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import Foundation
import PipelineModels

// MARK: - Pipeline Request Protocol

/// Base protocol for all Utterance requests.
///
/// This follows Alamofire's `Request` pattern, providing a unified interface
/// for all pipeline operations (recording, transcription, translation).
///
/// ## Overview
///
/// All request types conform to this protocol, enabling:
/// - Lifecycle management (resume, suspend, cancel)
/// - State observation
/// - Chainable response handling
///
/// ```swift
/// let request = UT.record(.default)
/// await request.resume()
/// // ... later ...
/// await request.cancel()
/// ```
public protocol PipelineRequest: AnyObject, Sendable {

    /// The output type produced by this request
    associatedtype Output: Sendable

    /// Unique identifier for this request
    var id: RequestID { get }

    /// Current state of the request
    var state: RequestState { get async }

    /// Number of retry attempts made for this request
    var retryCount: Int { get async }

    // MARK: - Lifecycle

    /// Resumes the request if suspended or starts if initialized.
    func resume() async

    /// Suspends the request, pausing processing.
    func suspend() async

    /// Cancels the request, stopping all processing.
    func cancel() async

    // MARK: - Execution

    /// Executes the request and returns the result.
    /// - Returns: The output of the request
    /// - Throws: `UtteranceError` if the request fails
    func run() async throws -> Output
}

// MARK: - Event Handlers

/// Closure types for request event handling
public typealias VoidHandler = @Sendable () -> Void
public typealias ErrorHandler = @Sendable (UtteranceError) -> Void

// MARK: - Response Handling

/// Protocol for requests that support closure-based response handling.
public protocol ResponseHandling: PipelineRequest {

    /// Adds a completion handler called when the request finishes.
    /// - Parameters:
    ///   - queue: The dispatch queue to call the handler on (default: main)
    ///   - completion: The completion handler
    /// - Returns: Self for chaining
    @discardableResult
    func response(
        queue: DispatchQueue,
        completion: @escaping @Sendable (Result<Output, UtteranceError>) -> Void
    ) -> Self
}

extension ResponseHandling {
    /// Adds a completion handler on the main queue.
    @discardableResult
    public func response(
        completion: @escaping @Sendable (Result<Output, UtteranceError>) -> Void
    ) -> Self {
        response(queue: .main, completion: completion)
    }
}

// MARK: - Lifecycle Hooks

/// Protocol for requests that support lifecycle event hooks.
public protocol LifecycleHooks: PipelineRequest {

    /// Called just before the request starts.
    @discardableResult
    func willStart(_ handler: @escaping VoidHandler) -> Self

    /// Called when the request completes successfully.
    @discardableResult
    func didComplete(_ handler: @escaping @Sendable (Output) -> Void) -> Self

    /// Called when the request fails.
    @discardableResult
    func didFail(_ handler: @escaping ErrorHandler) -> Self
}
