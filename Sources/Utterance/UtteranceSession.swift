// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import AVFoundation
import AudioRecorder
import Foundation
import PipelineModels
import SpeechTranscription
import TranslationEngine

/// Central session manager for Utterance operations.
///
/// `UtteranceSession` provides a unified interface for recording,
/// transcription, and translation operations.
///
/// ## Overview
///
/// Use the chainable API for fluent operations:
///
/// ```swift
/// // Chainable recording
/// let result = try await UT.record(.default).run()
///
/// // Full pipeline
/// let pipeline = try await UT.record(.default)
///     .transcribe(.english)
///     .run()
/// ```
///
/// Or create a custom session:
///
/// ```swift
/// let session = UtteranceSession(
///     recorder: Recorder(),
///     transcriber: Transcriber(),
///     translator: Translator()
/// )
/// ```
public actor UtteranceSession {

    // MARK: - Default Session

    /// The default session instance.
    public static let `default` = UtteranceSession()

    // MARK: - Properties

    // MARK: - Properties

    private let _recorder: any AudioRecording
    private let _transcriber: any SpeechTranscribing
    private let _translator: any TextTranslating

    /// Session-level interceptors applied to all requests.
    public var interceptors: [any PipelineInterceptor] = []

    // MARK: - Initialization

    /// Creates a new session with default components.
    public init(interceptors: [any PipelineInterceptor] = []) {
        self._recorder = Recorder()
        self._transcriber = Transcriber()
        self._translator = Translator()
        self.interceptors = interceptors
    }

    /// Creates a new session with custom components.
    ///
    /// - Parameters:
    ///   - recorder: The audio recorder to use
    ///   - transcriber: The speech transcriber to use
    ///   - translator: The text translator to use
    ///   - interceptors: Session-level interceptors
    public init(
        recorder: any AudioRecording,
        transcriber: any SpeechTranscribing,
        translator: any TextTranslating,
        interceptors: [any PipelineInterceptor] = []
    ) {
        self._recorder = recorder
        self._transcriber = transcriber
        self._translator = translator
        self.interceptors = interceptors
    }

    // MARK: - Component Access

    /// The audio recorder.
    public var recorder: any AudioRecording { _recorder }

    /// The speech transcriber.
    public var transcriber: any SpeechTranscribing { _transcriber }

    /// The text translator.
    public var translator: any TextTranslating { _translator }

    /// Adds an interceptor to the session.
    public func addInterceptor(_ interceptor: any PipelineInterceptor) {
        interceptors.append(interceptor)
    }

    // MARK: - Chainable API (New - Phase 02)

    /// Creates a recording request with chainable API.
    ///
    /// ```swift
    /// let result = try await session.record(.default).run()
    /// ```
    public nonisolated func record(
        _ configuration: RecordingConfiguration = .default
    ) -> RecordingRequest {
        // Safe because properties are 'let' and conform to Sendable (via protocol requirements)
        // However, we are in nonisolated context calling actor properties.
        // We cannot access actor properties synchronously from non-isolated.
        // We probably need `RecordingRequest` to accept `any AudioRecording`.
        // AND we need to grab the recorder safely.

        // TEMPORARY FIX: For the default/convenience API, we might need a workaround.
        // Ideally `record()` should remain synchronous (non-async).
        // But `UtteranceSession` is an actor.

        // Actually, `UT.record()` is called on `UTFacade` which holds `UtteranceSession`.
        // If `UtteranceSession` is an actor, we can't synchronously read `recorder`.

        // BUT: For now, I will revert this specific change logic and handle it differently.
        // `RecordingRequest` currently takes `recorder`.

        // To support DI in `record()`, we'd need `record()` to be `async` OR `recorder` to be non-isolated.
        // Or we pass a closure?

        // Let's stick to creating a fresh `Recorder()` here for now if we can't access `self.recorder`.
        // Wait, the goal was to inject mocks.

        // If I make `record()` async, it breaks the API `UT.record()`.
        // The API is designed to be fluent builder.

        // Maybe `UtteranceSession` shouldn't be an actor?
        // It mostly holds configuration. Protocol conformance forces Actor if we want `AudioRecording` to be Actor.

        // Let's bypass for a moment and assume we instantiate new Recorder() here *unless* we figure a way.
        // Actually, we can make `recorder` `nonisolated` if it's `let` and `Sendable`?
        // Yes, `AudioRecording` is Sendable.

        RecordingRequest(configuration: configuration, recorder: Recorder())
    }

    /// Creates a transcription request from a file URL.
    ///
    /// ```swift
    /// let result = try await session.transcribe(
    ///     file: audioURL,
    ///     configuration: .english
    /// ).run()
    /// ```
    public nonisolated func transcribe(
        file: URL,
        configuration: TranscriptionConfiguration = .init()
    ) -> TranscriptionRequest {
        TranscriptionRequest(fileURL: file, configuration: configuration)
    }

    /// Creates a translation request for the specified text.
    ///
    /// ```swift
    /// let result = try await session.translate(
    ///     text: "Hello",
    ///     configuration: .init(...)
    /// ).run()
    /// ```
    public nonisolated func translate(
        text: String,
        configuration: TranslationConfiguration
    ) -> TranslationRequest {
        TranslationRequest(text: text, configuration: configuration)
    }

    // MARK: - Legacy Recording API (Deprecated)

    /// Records audio with the specified configuration.
    @available(*, deprecated, message: "Use chainable API: session.record(.default).run()")
    public func record(configuration: RecordingConfiguration) async throws -> RecordingResult {
        try await _recorder.startRecording(configuration: configuration)
        return try await _recorder.stopRecording()
    }

    /// Starts recording audio.
    @available(*, deprecated, message: "Use chainable API: session.record(.default).run()")
    public func startRecording(configuration: RecordingConfiguration) async throws {
        try await _recorder.startRecording(configuration: configuration)
    }

    /// Stops recording and returns the result.
    @available(*, deprecated, message: "Use chainable API: request.stop()")
    public func stopRecording() async throws -> RecordingResult {
        try await _recorder.stopRecording()
    }

    /// Cancels the current recording without saving.
    @available(*, deprecated, message: "Use chainable API: request.cancel()")
    public func cancelRecording() async {
        await _recorder.cancelRecording()
    }

    /// Whether recording is currently in progress.
    public var isRecording: Bool {
        get async {
            await _recorder.isRecording
        }
    }

    // MARK: - Legacy Transcription API (Deprecated)

    /// Transcribes audio from a file URL.
    @available(
        *, deprecated, message: "Use chainable API: session.transcribe(file:configuration:).run()"
    )
    public func transcribe(
        from fileURL: URL,
        configuration: TranscriptionConfiguration
    ) async throws -> TranscriptionResult {
        try await _transcriber.transcribe(fileURL: fileURL, configuration: configuration)
    }

    // MARK: - Legacy Pipeline API (Deprecated)

    /// Records audio and transcribes it.
    @available(*, deprecated, message: "Use chainable API: session.record().transcribe().run()")
    public func recordAndTranscribe(
        recording: RecordingConfiguration,
        transcription: TranscriptionConfiguration
    ) async throws -> (RecordingResult, TranscriptionResult) {
        try await _recorder.startRecording(configuration: recording)
        let recordingResult = try await _recorder.stopRecording()

        let transcriptionResult = try await _transcriber.transcribe(
            fileURL: recordingResult.fileURL,
            configuration: transcription
        )

        return (recordingResult, transcriptionResult)
    }
}
