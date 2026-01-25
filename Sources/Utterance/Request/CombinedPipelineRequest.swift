// The MIT License (MIT)
// Copyright (c) 2024 Utterance

@preconcurrency import AVFoundation
import AudioRecorder
import Foundation
import PipelineModels
import SpeechTranscription
import TranslationEngine
/// A request combining multiple pipeline stages.
///
/// `CombinedPipelineRequest` chains recording, transcription, and translation
/// into a single cohesive operation.
///
/// ## Overview
///
/// Create combined requests by chaining:
///
/// ```swift
/// let result = try await UT.record(.default)
///     .transcribe(.english)
///     .translate(.toVietnamese)
///     .run()
///
/// print(result.recording?.duration)
/// print(result.transcription?.text)
/// print(result.translation?.translatedText)
/// ```
import os

// MARK: - Pipeline Output

/// Combined output from a multi-stage pipeline.
public struct PipelineOutput: Sendable {

    /// Recording result (if recording was performed)
    public let recording: RecordingResult?

    /// Transcription result (if transcription was performed)
    public let transcription: TranscriptionResult?

    /// Translation result (if translation was performed)
    public let translation: TranslationResult?

    public init(
        recording: RecordingResult? = nil,
        transcription: TranscriptionResult? = nil,
        translation: TranslationResult? = nil
    ) {
        self.recording = recording
        self.transcription = transcription
        self.translation = translation
    }
}

// MARK: - Combined Pipeline Request

// ...

public final class CombinedPipelineRequest: @unchecked Sendable {

    // MARK: - Properties

    /// Unique identifier for this request
    public let id: RequestID

    /// Lock for thread-safe access to mutable properties
    private let lock = OSAllocatedUnfairLock()

    /// Current state
    private let stateActor = StateActor()

    // MARK: - Pipeline Components

    private var recordingRequest: RecordingRequest?
    private var transcriptionRequest: TranscriptionRequest?
    private var translationRequest: TranslationRequest?

    private var transcriptionConfiguration: TranscriptionConfiguration?
    private var translationConfiguration: TranslationConfiguration?

    // MARK: - Handlers

    private var waveformHandler: (@Sendable ([Float]) -> Void)?
    private var waveformDownsampleFactor: Int = 4
    private var recordingProgressHandler: (@Sendable (RecordingProgress) -> Void)?
    private var transcriptionProgressHandler: (@Sendable (TranscriptionProgress) -> Void)?
    private var willStartHandler: VoidHandler?
    private var didCompleteHandler: (@Sendable (PipelineOutput) -> Void)?
    private var didFailHandler: ErrorHandler?
    private var responseCompletion: (@Sendable (Result<PipelineOutput, UtteranceError>) -> Void)?
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

    /// Creates from a recording request + transcription config.
    init(
        recordingRequest: RecordingRequest,
        transcriptionConfiguration: TranscriptionConfiguration
    ) {
        self.id = RequestID()
        self.recordingRequest = recordingRequest
        self.transcriptionConfiguration = transcriptionConfiguration
    }

    /// Creates from a transcription request + translation config.
    init(
        transcriptionRequest: TranscriptionRequest,
        translationConfiguration: TranslationConfiguration
    ) {
        self.id = RequestID()
        self.transcriptionRequest = transcriptionRequest
        self.translationConfiguration = translationConfiguration
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

// MARK: - Chainable Methods

extension CombinedPipelineRequest {

    /// Adds translation after transcription.
    public func translate(_ configuration: TranslationConfiguration) -> Self {
        lock.withLock {
            self.translationConfiguration = configuration
        }
        return self
    }

    /// Adds waveform visualization (only if recording is included).
    @discardableResult
    public func waveform(
        downsampleFactor: Int = 4,
        handler: @escaping @Sendable ([Float]) -> Void
    ) -> Self {
        lock.withLock {
            self.waveformDownsampleFactor = downsampleFactor
            self.waveformHandler = handler
        }
        return self
    }

    /// Adds recording progress handler.
    @discardableResult
    public func onRecordingProgress(
        _ handler: @escaping @Sendable (RecordingProgress) -> Void
    ) -> Self {
        lock.withLock {
            self.recordingProgressHandler = handler
        }
        return self
    }

    /// Adds transcription progress handler.
    @discardableResult
    public func onTranscriptionProgress(
        _ handler: @escaping @Sendable (TranscriptionProgress) -> Void
    ) -> Self {
        lock.withLock {
            self.transcriptionProgressHandler = handler
        }
        return self
    }
}

// MARK: - PipelineRequestProtocol

extension CombinedPipelineRequest: PipelineRequest {

    public typealias Output = PipelineOutput

    /// Starts the combined pipeline.
    public func resume() async {
        let currentState = await stateActor.state
        guard currentState == .initialized else { return }

        await stateActor.setState(.running)
        willStartHandler?()

        do {
            // Step 1: Recording (if present)
            if let recordingReq = recordingRequest {
                // Configure waveform if set
                if let handler = waveformHandler {
                    recordingReq.waveform(
                        downsampleFactor: waveformDownsampleFactor,
                        handler: handler
                    )
                }

                if let progressHandler = recordingProgressHandler {
                    recordingReq.onProgress(progressHandler)
                }

                // Hook into failures
                recordingReq.didFail { [weak self] error in
                    Task { [weak self] in
                        await self?.handleError(error)
                    }
                }

                // Start recording
                await recordingReq.resume()

                // Note: Recording needs to be stopped externally
                // For the combined pipeline, we wait for stop() to be called.
                // WE RETURN HERE to keep the state as .running
                return
            }

            // Step 2 & 3: Transcription & Translation (without recording)
            // If we are here, it means we don't have a recording request,
            // so we proceed immediately.

            var transcriptionResult: TranscriptionResult?
            var translationResult: TranslationResult?

            // Transcription
            if let transcriptionReq = transcriptionRequest {
                transcriptionResult = try await transcriptionReq.run()
            }

            // Translation
            if let translationConfig = translationConfiguration,
                let transcriptionRes = transcriptionResult
            {
                let translator = Translator()
                translationResult = try await translator.translate(
                    text: transcriptionRes.text,
                    configuration: translationConfig
                )
            }

            // Note: If we had no recording and no transcription request,
            // we might end up with empty results. This is an invalid config case
            // but we handle it gracefully by returning what we have.

            let output = PipelineOutput(
                recording: nil,
                transcription: transcriptionResult,
                translation: translationResult
            )

            await stateActor.setState(.finished)
            didCompleteHandler?(output)
            responseQueue.async { [responseCompletion] in
                responseCompletion?(.success(output))
            }

        } catch let error as UtteranceError {
            await handleError(error)
        } catch {
            await handleError(.recording(.engineStartFailed(reason: error.localizedDescription)))
        }
    }

    /// Suspends the pipeline.
    public func suspend() async {
        await recordingRequest?.suspend()
    }

    /// Cancels the pipeline.
    public func cancel() async {
        await stateActor.setState(.cancelling)
        await recordingRequest?.cancel()
        await transcriptionRequest?.cancel()
        await translationRequest?.cancel()
        await stateActor.setState(.finished)
    }

    /// Executes the pipeline and returns the combined result.
    public func run() async throws -> PipelineOutput {
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

    /// Stops recording and completes the pipeline.
    @discardableResult
    public func stopRecording() async throws -> PipelineOutput {
        guard await stateActor.state == .running else {
            // If not running, maybe it failed?
            throw UtteranceError.recording(
                .invalidConfiguration(
                    reason: "Pipeline is not running (state: \(await stateActor.state))"))
        }

        guard let recordingReq = recordingRequest else {
            throw UtteranceError.recording(
                .invalidConfiguration(reason: "No recording in pipeline"))
        }

        // Stop the recording
        let recordingResult = try await recordingReq.stop()

        // Continue with transcription and translation
        var transcriptionResult: TranscriptionResult?
        var translationResult: TranslationResult?

        // Transcribe
        if let transcriptionConfig = transcriptionConfiguration {
            let transcriber = Transcriber()
            transcriptionResult = try await transcriber.transcribe(
                fileURL: recordingResult.fileURL,
                configuration: transcriptionConfig
            )
        }

        // Translate
        if let translationConfig = translationConfiguration,
            let transcriptionRes = transcriptionResult
        {
            let translator = Translator()
            translationResult = try await translator.translate(
                text: transcriptionRes.text,
                configuration: translationConfig
            )
        }

        let output = PipelineOutput(
            recording: recordingResult,
            transcription: transcriptionResult,
            translation: translationResult
        )

        await stateActor.setState(.finished)
        didCompleteHandler?(output)
        responseQueue.async { [responseCompletion] in
            responseCompletion?(.success(output))
        }

        return output
    }
}

// MARK: - ResponseHandling

extension CombinedPipelineRequest: ResponseHandling {

    @discardableResult
    public func response(
        queue: DispatchQueue,
        completion: @escaping @Sendable (Result<PipelineOutput, UtteranceError>) -> Void
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

extension CombinedPipelineRequest: LifecycleHooks {

    @discardableResult
    public func willStart(_ handler: @escaping VoidHandler) -> Self {
        lock.withLock {
            self.willStartHandler = handler
        }
        return self
    }

    @discardableResult
    public func didComplete(_ handler: @escaping @Sendable (PipelineOutput) -> Void) -> Self {
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

extension CombinedPipelineRequest {

    private func handleError(_ error: UtteranceError) async {
        await stateActor.setState(.finished)
        didFailHandler?(error)
        responseQueue.async { [responseCompletion] in
            responseCompletion?(.failure(error))
        }
    }
}
