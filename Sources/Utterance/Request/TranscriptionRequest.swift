// The MIT License (MIT)
// Copyright (c) 2024 Utterance

@preconcurrency import AVFoundation
import Foundation
import PipelineModels
import SpeechTranscription
/// A request for speech transcription operations.
///
/// `TranscriptionRequest` provides a chainable API for speech-to-text conversion.
///
/// ## Overview
///
/// Create requests using the `UT` shorthand:
///
/// ```swift
/// // From audio file
/// let result = try await UT.transcribe(
///     file: audioURL,
///     configuration: .english
/// ).run()
///
/// // With streaming updates
/// UT.transcribe(file: audioURL, configuration: .english)
///     .onPartialResult { partial in
///         label.text = partial
///     }
///     .response { result in
///         print(result)
///     }
/// ```
import os

// MARK: - Transcription Request

// ...

public final class TranscriptionRequest: @unchecked Sendable {

    // MARK: - Properties

    /// Unique identifier for this request
    public let id: RequestID

    /// Lock for thread-safe access to mutable properties
    private let lock = OSAllocatedUnfairLock()

    /// The transcription configuration
    public let configuration: TranscriptionConfiguration

    /// Source: either a file URL or buffer stream (set internally)
    private var sourceFileURL: URL?
    private var sourceBufferStream: AsyncStream<AVAudioPCMBuffer>?

    /// Current state
    private let stateActor = StateActor()

    /// The underlying transcriber
    private let transcriber: Transcriber

    // MARK: - Handlers

    private var partialResultHandler: (@Sendable (String) -> Void)?
    private var progressHandler: (@Sendable (TranscriptionProgress) -> Void)?
    private var willStartHandler: VoidHandler?
    private var didCompleteHandler: (@Sendable (TranscriptionResult) -> Void)?
    private var didFailHandler: ErrorHandler?
    private var responseCompletion:
        (@Sendable (Result<TranscriptionResult, UtteranceError>) -> Void)?
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

    /// Creates a transcription request from a file URL.
    public init(
        fileURL: URL,
        configuration: TranscriptionConfiguration,
        transcriber: Transcriber = Transcriber()
    ) {
        self.id = RequestID()
        self.configuration = configuration
        self.sourceFileURL = fileURL
        self.transcriber = transcriber
    }

    /// Creates a transcription request from a buffer stream.
    public init(
        bufferStream: AsyncStream<AVAudioPCMBuffer>,
        configuration: TranscriptionConfiguration,
        transcriber: Transcriber = Transcriber()
    ) {
        self.id = RequestID()
        self.configuration = configuration
        self.sourceBufferStream = bufferStream
        self.transcriber = transcriber
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

extension TranscriptionRequest: PipelineRequest {

    public typealias Output = TranscriptionResult

    /// Starts or resumes transcription.
    public func resume() async {
        let currentState = await stateActor.state
        guard currentState == .initialized else { return }

        await stateActor.setState(.running)

        let startHandler = lock.withLock { willStartHandler }
        startHandler?()

        do {
            let result: TranscriptionResult

            if let fileURL = sourceFileURL {
                // File-based transcription
                result = try await transcriber.transcribe(
                    fileURL: fileURL,
                    configuration: configuration
                )
            } else if let bufferStream = sourceBufferStream {
                // Stream-based transcription
                var finalResult: TranscriptionResult?

                // Wrap bufferStream to silence Sendable warning (we accept ownership here)
                struct UnsafeStreamWrapper: @unchecked Sendable {
                    let stream: AsyncStream<AVAudioPCMBuffer>
                }
                let wrapper = UnsafeStreamWrapper(stream: bufferStream)

                // Map to SendableAudioBuffer stream
                let sendableStream = AsyncStream<SendableAudioBuffer> { continuation in
                    Task {
                        for await buffer in wrapper.stream {
                            continuation.yield(SendableAudioBuffer(buffer))
                        }
                        continuation.finish()
                    }
                }

                let stream = await transcriber.transcribeStream(
                    buffers: sendableStream,
                    configuration: configuration
                )

                for try await partialResult in stream {
                    // Report partial results
                    // Retrieve handlers safely for each iteration
                    let (partialHandler, progHandler) = lock.withLock {
                        (partialResultHandler, progressHandler)
                    }

                    partialHandler?(partialResult.text)

                    let progress = TranscriptionProgress(
                        partialText: partialResult.text,
                        confidence: partialResult.confidence,
                        isFinal: partialResult.isFinal,
                        segments: partialResult.segments.map { segment in
                            TranscriptionSegment(
                                text: segment.text,
                                timestamp: segment.timestamp,
                                duration: segment.duration,
                                confidence: segment.confidence
                            )
                        }
                    )
                    progHandler?(progress)

                    if partialResult.isFinal {
                        finalResult = partialResult
                        break
                    }
                }

                guard let final = finalResult else {
                    throw UtteranceError.transcription(.noSpeechDetected)
                }
                result = final
            } else {
                throw UtteranceError.transcription(
                    .invalidAudioFormat(reason: "No source specified"))
            }

            await stateActor.setState(.finished)

            let (completeHandler, queue, completion) = lock.withLock {
                (didCompleteHandler, responseQueue, responseCompletion)
            }

            completeHandler?(result)
            queue.async {
                completion?(.success(result))
            }

        } catch let error as UtteranceError {
            await handleError(error)
        } catch {
            await handleError(
                .transcription(.recognitionFailed(reason: error.localizedDescription)))
        }
    }

    // ...

    /// Suspends transcription.
    public func suspend() async {
        // Note: Speech recognition cannot be truly suspended
        // This is kept for protocol conformance
    }

    /// Cancels transcription.
    public func cancel() async {
        await stateActor.setState(.cancelling)
        await stateActor.setState(.finished)
    }

    /// Executes transcription and returns the result.
    public func run() async throws -> TranscriptionResult {
        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                self.responseCompletion = { result in
                    switch result {
                    case .success(let output):
                        continuation.resume(returning: output)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }

            Task {
                await self.resume()
            }
        }
    }
}

// MARK: - Chainable Methods

extension TranscriptionRequest {

    /// Adds a handler for partial transcription results.
    @discardableResult
    public func onPartialResult(
        _ handler: @escaping @Sendable (String) -> Void
    ) -> Self {
        lock.withLock {
            self.partialResultHandler = handler
        }
        return self
    }

    /// Adds a progress handler.
    @discardableResult
    public func onProgress(
        _ handler: @escaping @Sendable (TranscriptionProgress) -> Void
    ) -> Self {
        lock.withLock {
            self.progressHandler = handler
        }
        return self
    }

    /// Chains translation after transcription.
    public func translate(
        _ configuration: TranslationConfiguration
    ) -> CombinedPipelineRequest {
        CombinedPipelineRequest(
            transcriptionRequest: self,
            translationConfiguration: configuration
        )
    }
}

// MARK: - ResponseHandling

extension TranscriptionRequest: ResponseHandling {

    @discardableResult
    public func response(
        queue: DispatchQueue,
        completion: @escaping @Sendable (Result<TranscriptionResult, UtteranceError>) -> Void
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

extension TranscriptionRequest: LifecycleHooks {

    @discardableResult
    public func willStart(_ handler: @escaping VoidHandler) -> Self {
        lock.withLock {
            self.willStartHandler = handler
        }
        return self
    }

    @discardableResult
    public func didComplete(_ handler: @escaping @Sendable (TranscriptionResult) -> Void) -> Self {
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

extension TranscriptionRequest {

    private func handleError(_ error: UtteranceError) async {
        await stateActor.setState(.finished)

        let (failHandler, queue, completion) = lock.withLock {
            (didFailHandler, responseQueue, responseCompletion)
        }

        failHandler?(error)
        queue.async {
            completion?(.failure(error))
        }
    }
}
