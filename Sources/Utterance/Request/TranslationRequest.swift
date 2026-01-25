// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import Foundation
import PipelineModels
import TranslationEngine
/// A request for text translation operations.
///
/// `TranslationRequest` provides a chainable API for translating text.
///
/// ## Overview
///
/// Create requests using the `UT` shorthand:
///
/// ```swift
/// let result = try await UT.translate(
///     text: "Hello, World!",
///     configuration: .toVietnamese
/// ).run()
///
/// print(result.translatedText)
/// ```
import os

// MARK: - Translation Request

// ...

public final class TranslationRequest: @unchecked Sendable {

    // MARK: - Properties

    /// Unique identifier for this request
    public let id: RequestID

    /// Lock for thread-safe access to mutable properties
    private let lock = OSAllocatedUnfairLock()

    /// The translation configuration
    public let configuration: TranslationConfiguration

    /// Source text to translate
    private let sourceText: String

    /// Current state
    private let stateActor = StateActor()

    /// The underlying translator
    private let translator: Translator

    // MARK: - Handlers

    private var willStartHandler: VoidHandler?
    private var didCompleteHandler: (@Sendable (TranslationResult) -> Void)?
    private var didFailHandler: ErrorHandler?
    private var responseCompletion: (@Sendable (Result<TranslationResult, UtteranceError>) -> Void)?
    private var responseQueue: DispatchQueue = .main

    // MARK: - Internal State Actor

    private actor StateActor {
        var state: RequestState = .initialized
        var retryCount: Int = 0

        func setState(_ newState: RequestState) {
            state = newState
        }

        func incrementRetry() -> Int {
            retryCount += 1
            return retryCount
        }
    }

    // MARK: - Initialization

    /// Creates a translation request.
    public init(
        text: String,
        configuration: TranslationConfiguration,
        translator: Translator = Translator()
    ) {
        self.id = RequestID()
        self.sourceText = text
        self.configuration = configuration
        self.translator = translator
    }

    // MARK: - State Access

    /// Current state of the request
    public var state: RequestState {
        get async {
            await stateActor.state
        }
    }

    /// Number of retry attempts
    public var retryCount: Int {
        get async {
            await stateActor.retryCount
        }
    }
}

// MARK: - PipelineRequestProtocol

extension TranslationRequest: PipelineRequest {

    public typealias Output = TranslationResult

    /// Starts translation.
    public func resume() async {
        let currentState = await stateActor.state
        guard currentState == .initialized else { return }

        await stateActor.setState(.running)
        willStartHandler?()

        do {
            let result = try await translator.translate(
                text: sourceText,
                configuration: configuration
            )

            await stateActor.setState(.finished)
            didCompleteHandler?(result)
            responseQueue.async { [responseCompletion] in
                responseCompletion?(.success(result))
            }

        } catch let error as UtteranceError {
            await handleError(error)
        } catch {
            await handleError(.translation(.translationFailed(reason: error.localizedDescription)))
        }
    }

    /// Suspends translation (not applicable for translation).
    public func suspend() async {
        // Translation cannot be suspended
    }

    /// Cancels translation.
    public func cancel() async {
        await stateActor.setState(.cancelling)
        await stateActor.setState(.finished)
    }

    /// Executes translation and returns the result.
    public func run() async throws -> TranslationResult {
        return try await withCheckedThrowingContinuation { continuation in
            self.responseCompletion = { result in
                switch result {
                case .success(let output):
                    continuation.resume(returning: output)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            Task {
                await self.resume()
            }
        }
    }
}

// MARK: - ResponseHandling

// MARK: - ResponseHandling

extension TranslationRequest: ResponseHandling {

    @discardableResult
    public func response(
        queue: DispatchQueue,
        completion: @escaping @Sendable (Result<TranslationResult, UtteranceError>) -> Void
    ) -> Self {
        lock.withLock {
            self.responseQueue = queue
            self.responseCompletion = completion
        }

        Task {
            await self.resume()
        }

        return self
    }
}

// MARK: - LifecycleHooks

extension TranslationRequest: LifecycleHooks {

    @discardableResult
    public func willStart(_ handler: @escaping VoidHandler) -> Self {
        lock.withLock {
            self.willStartHandler = handler
        }
        return self
    }

    @discardableResult
    public func didComplete(_ handler: @escaping @Sendable (TranslationResult) -> Void) -> Self {
        lock.withLock {
            self.didCompleteHandler = handler
        }
        return self
    }

    @discardableResult
    public func didFail(_ handler: @escaping ErrorHandler) -> Self {
        lock.withLock {
            self.didFailHandler = handler
        }
        return self
    }
}

// MARK: - Private Methods

extension TranslationRequest {

    private func handleError(_ error: UtteranceError) async {
        await stateActor.setState(.finished)
        didFailHandler?(error)
        responseQueue.async { [responseCompletion] in
            responseCompletion?(.failure(error))
        }
    }
}
