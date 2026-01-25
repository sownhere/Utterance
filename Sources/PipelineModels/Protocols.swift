// The MIT License (MIT)
//
// Copyright (c) 2024 Utterance
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@preconcurrency import AVFoundation
import Foundation

// MARK: - Audio Recording Protocol

/// Protocol for audio recording implementations.
///
/// Conforming types handle audio capture from the device's microphone,
/// providing both file output and streaming audio buffers.
///
/// Example implementation usage:
/// ```swift
/// let recorder: any AudioRecording = Recorder()
/// try await recorder.startRecording(configuration: .default)
///
/// // Access streaming buffers
/// for await buffer in await recorder.audioBufferStream {
///     // Process buffer
/// }
///
/// let result = try await recorder.stopRecording()
/// ```
public protocol AudioRecording: Actor, Sendable {

    /// Starts recording audio with the specified configuration.
    ///
    /// - Parameter configuration: The recording configuration
    /// - Throws: ``UtteranceError/recording(_:)`` if recording fails to start
    func startRecording(configuration: RecordingConfiguration) async throws

    /// Stops the current recording and returns the result.
    ///
    /// - Returns: The recording result containing file URL and duration
    /// - Throws: ``UtteranceError/recording(_:)`` if stopping fails
    func stopRecording() async throws -> RecordingResult

    /// Cancels the current recording without saving.
    func cancelRecording() async

    /// Stream of audio buffers captured during recording.
    ///
    /// Use this stream to access raw audio data for real-time processing
    /// such as speech recognition.
    var audioBufferStream: AsyncStream<AVAudioPCMBuffer> { get async }

    /// Stream of sendable audio buffers.
    ///
    /// Use this for actor-crossing stream consumption.
    var sendableAudioBufferStream: AsyncStream<SendableAudioBuffer> { get async }

    /// Whether recording is currently in progress.
    var isRecording: Bool { get async }
}

// MARK: - Speech Transcription Protocol

/// Protocol for speech transcription implementations.
///
/// Conforming types handle converting audio to text using speech recognition.
///
/// Example implementation usage:
/// ```swift
/// let transcriber: any SpeechTranscribing = Transcriber()
///
/// // Single buffer transcription
/// let result = try await transcriber.transcribe(
///     buffer: audioBuffer,
///     configuration: .english
/// )
///
/// // Streaming transcription
/// for try await result in transcriber.transcribeStream(
///     buffers: bufferStream,
///     configuration: .english
/// ) {
///     print(result.text)
/// }
/// ```
public protocol SpeechTranscribing: Actor, Sendable {

    /// Transcribes a single audio buffer.
    ///
    /// - Parameters:
    ///   - buffer: The audio buffer to transcribe
    ///   - configuration: The transcription configuration
    /// - Returns: The transcription result
    /// - Throws: ``UtteranceError/transcription(_:)`` if transcription fails
    func transcribe(
        buffer: AVAudioPCMBuffer,
        configuration: TranscriptionConfiguration
    ) async throws -> TranscriptionResult

    /// Transcribes audio from a file URL.
    ///
    /// - Parameters:
    ///   - fileURL: URL of the audio file to transcribe
    ///   - configuration: The transcription configuration
    /// - Returns: The transcription result
    /// - Throws: ``UtteranceError/transcription(_:)`` if transcription fails
    func transcribe(
        fileURL: URL,
        configuration: TranscriptionConfiguration
    ) async throws -> TranscriptionResult

    /// Transcribes a stream of audio buffers.
    ///
    /// Returns an async stream of transcription results that updates
    /// as more audio is processed.
    ///
    /// - Parameters:
    ///   - buffers: Stream of audio buffers to transcribe
    ///   - configuration: The transcription configuration
    /// - Returns: Async stream of transcription results
    func transcribeStream(
        buffers: AsyncStream<SendableAudioBuffer>,
        configuration: TranscriptionConfiguration
    ) -> AsyncThrowingStream<TranscriptionResult, Error>
}

// MARK: - Text Translation Protocol

/// Protocol for text translation implementations.
///
/// Conforming types handle translating text between languages.
///
/// Example implementation usage:
/// ```swift
/// let translator: any TextTranslating = Translator()
///
/// // Single text translation
/// let result = try await translator.translate(
///     text: "Hello, world!",
///     configuration: .englishToVietnamese
/// )
///
/// // Streaming translation
/// for try await result in translator.translateStream(
///     texts: textStream,
///     configuration: .englishToVietnamese
/// ) {
///     print(result.translatedText)
/// }
/// ```
public protocol TextTranslating: Actor, Sendable {

    /// Translates a single text string.
    ///
    /// - Parameters:
    ///   - text: The text to translate
    ///   - configuration: The translation configuration
    /// - Returns: The translation result
    /// - Throws: ``UtteranceError/translation(_:)`` if translation fails
    func translate(
        text: String,
        configuration: TranslationConfiguration
    ) async throws -> TranslationResult

    /// Translates a stream of text strings.
    ///
    /// - Parameters:
    ///   - texts: Stream of texts to translate
    ///   - configuration: The translation configuration
    /// - Returns: Async stream of translation results
    func translateStream(
        texts: AsyncStream<String>,
        configuration: TranslationConfiguration
    ) -> AsyncThrowingStream<TranslationResult, Error>
}

// MARK: - Pipeline Protocol

/// Protocol for the complete speech pipeline.
///
/// Conforming types provide a unified interface for recording,
/// transcription, and translation operations.
public protocol SpeechPipeline: Actor, Sendable {

    /// The audio recorder
    var recorder: any AudioRecording { get }

    /// The speech transcriber
    var transcriber: any SpeechTranscribing { get }

    /// The text translator
    var translator: any TextTranslating { get }

    /// Records audio and saves to file.
    ///
    /// - Parameter configuration: The recording configuration
    /// - Returns: The recording result
    func record(configuration: RecordingConfiguration) async throws -> RecordingResult

    /// Records audio and transcribes it.
    ///
    /// - Parameters:
    ///   - recording: The recording configuration
    ///   - transcription: The transcription configuration
    /// - Returns: Tuple of recording and transcription results
    func recordAndTranscribe(
        recording: RecordingConfiguration,
        transcription: TranscriptionConfiguration
    ) async throws -> (RecordingResult, TranscriptionResult)

    /// Records audio, transcribes it, and translates the transcription.
    ///
    /// - Parameters:
    ///   - recording: The recording configuration
    ///   - transcription: The transcription configuration
    ///   - translation: The translation configuration
    /// - Returns: Tuple of all three results
    func recordTranscribeAndTranslate(
        recording: RecordingConfiguration,
        transcription: TranscriptionConfiguration,
        translation: TranslationConfiguration
    ) async throws -> (RecordingResult, TranscriptionResult, TranslationResult)
}
