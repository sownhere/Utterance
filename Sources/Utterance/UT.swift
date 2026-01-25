// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import AudioRecorder
import Foundation
import PipelineModels
import SpeechTranscription
import TranslationEngine

/// Shorthand access to the default UtteranceSession.
///
/// Use `UT` for quick access to Utterance functionality with chainable API:
///
/// ```swift
/// // Chainable recording
/// let result = try await UT.record(.default).run()
///
/// // With waveform visualization
/// try await UT.record(.default)
///     .waveform { samples in waveformView.update(samples) }
///     .run()
///
/// // Full pipeline
/// let pipeline = try await UT.record(.default)
///     .transcribe(.english)
///     .translate(.toVietnamese)
///     .run()
/// ```
public let UT = UTFacade.shared

// MARK: - UT Facade

/// Main facade providing chainable API for Utterance operations.
///
/// This follows Alamofire's `AF` pattern, providing static factory methods
/// that return chainable request objects.
public final class UTFacade: @unchecked Sendable {

    /// Shared instance
    public static let shared = UTFacade()

    /// The underlying session
    public let session: UtteranceSession

    private init() {
        self.session = UtteranceSession.default
    }

    // MARK: - Recording

    /// Creates a recording request with the specified configuration.
    ///
    /// - Parameter configuration: The recording configuration
    /// - Returns: A chainable `RecordingRequest`
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Simple recording
    /// let result = try await UT.record(.default).run()
    ///
    /// // With waveform
    /// UT.record(.default)
    ///     .waveform { samples in
    ///         waveformView.update(with: samples)
    ///     }
    ///     .response { result in
    ///         print(result)
    ///     }
    /// ```
    public func record(_ configuration: RecordingConfiguration = .default) -> RecordingRequest {
        RecordingRequest(configuration: configuration)
    }

    // MARK: - Transcription

    /// Creates a transcription request from a file URL.
    ///
    /// - Parameters:
    ///   - file: URL of the audio file to transcribe
    ///   - configuration: The transcription configuration
    /// - Returns: A chainable `TranscriptionRequest`
    ///
    /// ## Example
    ///
    /// ```swift
    /// let result = try await UT.transcribe(
    ///     file: audioURL,
    ///     configuration: .english
    /// ).run()
    /// ```
    public func transcribe(
        file: URL,
        configuration: TranscriptionConfiguration = .init()
    ) -> TranscriptionRequest {
        TranscriptionRequest(fileURL: file, configuration: configuration)
    }

    // MARK: - Translation

    /// Creates a translation request for the specified text.
    ///
    /// - Parameters:
    ///   - text: The text to translate
    ///   - configuration: The translation configuration
    /// - Returns: A chainable `TranslationRequest`
    ///
    /// ## Example
    ///
    /// ```swift
    /// let result = try await UT.translate(
    ///     text: "Hello, World!",
    ///     configuration: .init(
    ///         sourceLanguage: .init(identifier: "en"),
    ///         targetLanguage: .init(identifier: "vi")
    ///     )
    /// ).run()
    /// ```
    public func translate(
        text: String,
        configuration: TranslationConfiguration
    ) -> TranslationRequest {
        TranslationRequest(text: text, configuration: configuration)
    }

    // MARK: - Legacy Access

    /// Access the underlying session for legacy API.
    @available(*, deprecated, message: "Use chainable API instead: UT.record().run()")
    public func startRecording(configuration: RecordingConfiguration) async throws {
        try await session.startRecording(configuration: configuration)
    }

    @available(*, deprecated, message: "Use chainable API instead: UT.record().run()")
    public func stopRecording() async throws -> RecordingResult {
        try await session.stopRecording()
    }
}
