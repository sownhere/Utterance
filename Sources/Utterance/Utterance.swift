// The MIT License (MIT)
// Copyright (c) 2024 Utterance

/// Utterance - A Swift speech pipeline library.
///
/// Utterance provides a unified API for audio recording, speech transcription,
/// and text translation using Apple's native frameworks.
///
/// ## Overview
///
/// Use the `UT` shorthand for quick access:
///
/// ```swift
/// import Utterance
///
/// // Record audio
/// try await UT.startRecording(configuration: .default)
/// // ... user speaks ...
/// let result = try await UT.stopRecording()
/// ```
///
/// ## Topics
///
/// ### Getting Started
/// - ``UT``
/// - ``UtteranceSession``
///
/// ### Recording
/// - ``Recorder``
/// - ``RecordingConfiguration``
/// - ``RecordingResult``
///
/// ### Transcription
/// - ``Transcriber``
/// - ``TranscriptionConfiguration``
/// - ``TranscriptionResult``
///
/// ### Translation
/// - ``Translator``
/// - ``TranslationConfiguration``
/// - ``TranslationResult``
///
/// ### Errors
/// - ``UtteranceError``
public enum Utterance {
    /// The current version of Utterance.
    public static let version = "0.1.0"
}

// MARK: - Re-exports

@_exported import PipelineModels
@_exported import AudioRecorder
@_exported import SpeechTranscription
@_exported import TranslationEngine
