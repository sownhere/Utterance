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
import AudioRecorder
import Foundation
import PipelineModels
@preconcurrency import Speech

/// Main speech transcription implementation conforming to ``SpeechTranscribing``.
///
/// The `Transcriber` actor provides a high-level interface for converting
/// speech to text using Apple's Speech framework.
///
/// ## Overview
///
/// Use `Transcriber` to convert audio to text. The transcriber supports
/// buffer transcription, streaming transcription, and file transcription.
///
/// ```swift
/// let transcriber = Transcriber()
///
/// // Transcribe from file
/// let result = try await transcriber.transcribe(
///     fileURL: audioFileURL,
///     configuration: .english
/// )
/// print("Transcription: \(result.text)")
///
/// // Streaming transcription from audio buffers
/// for try await result in transcriber.transcribeStream(
///     buffers: audioBufferStream,
///     configuration: .vietnamese
/// ) {
///     print("Partial: \(result.text), Final: \(result.isFinal)")
/// }
/// ```
public actor Transcriber: SpeechTranscribing {

    // MARK: - Properties

    private let recognizerManager: SpeechRecognizerManager
    private var taskManager: RecognitionTaskManager?

    // MARK: - Initialization

    /// Creates a new transcriber with a new recognizer manager.
    public init() {
        self.recognizerManager = SpeechRecognizerManager()
    }

    /// Creates a new transcriber with a custom recognizer manager.
    ///
    /// - Parameter recognizerManager: The recognizer manager to use
    public init(recognizerManager: SpeechRecognizerManager) {
        self.recognizerManager = recognizerManager
    }

    // MARK: - Authorization

    /// Requests speech recognition authorization.
    ///
    /// - Returns: The authorization status
    public func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await recognizerManager.requestAuthorization()
    }

    /// Gets the current authorization status.
    public nonisolated func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        recognizerManager.authorizationStatus()
    }

    // MARK: - SpeechTranscribing Protocol

    /// Transcribes a single audio buffer.
    ///
    /// This method creates a temporary recognition task, appends the buffer,
    /// and waits for the final result.
    ///
    /// - Parameters:
    ///   - buffer: The audio buffer to transcribe
    ///   - configuration: The transcription configuration
    /// - Returns: The transcription result
    /// - Throws: ``UtteranceError/transcription(_:)`` if transcription fails
    public func transcribe(
        buffer: AVAudioPCMBuffer,
        configuration: TranscriptionConfiguration
    ) async throws -> TranscriptionResult {
        // Request authorization
        let status = await recognizerManager.requestAuthorization()
        guard status == .authorized else {
            throw UtteranceError.permission(.speechRecognitionNotAuthorized)
        }

        // Get recognizer
        let recognizer = try await recognizerManager.getRecognizer(for: configuration.locale)

        // Create task manager
        let taskManager = RecognitionTaskManager()
        self.taskManager = taskManager

        // Create request and start recognition
        let request = taskManager.createRequest(configuration: configuration)
        let stream = taskManager.startRecognition(recognizer: recognizer, request: request)

        // Append buffer and finish
        taskManager.append(buffer: buffer)
        taskManager.endAudio()

        // Wait for final result
        var finalResult: TranscriptionResult?

        for try await result in stream {
            if result.isFinal {
                finalResult = result
                break
            }
        }

        self.taskManager = nil

        guard let result = finalResult else {
            throw UtteranceError.transcription(.noSpeechDetected)
        }

        return result
    }

    /// Transcribes a stream of audio buffers.
    ///
    /// Returns an async stream of transcription results that updates
    /// as more audio is processed.
    ///
    /// - Parameters:
    ///   - buffers: Stream of sendable audio buffers to transcribe
    ///   - configuration: The transcription configuration
    /// - Returns: Async stream of transcription results
    public func transcribeStream(
        buffers: AsyncStream<SendableAudioBuffer>,
        configuration: TranscriptionConfiguration
    ) -> AsyncThrowingStream<TranscriptionResult, Error> {
        // Capture what we need before creating the stream
        let recognizerManager = self.recognizerManager

        return AsyncThrowingStream { continuation in
            let task = Task { @Sendable in
                do {
                    // Request authorization
                    let status = await recognizerManager.requestAuthorization()
                    guard status == .authorized else {
                        continuation.finish(
                            throwing: UtteranceError.permission(.speechRecognitionNotAuthorized))
                        return
                    }

                    // Get recognizer
                    let recognizer = try await recognizerManager.getRecognizer(
                        for: configuration.locale)

                    // Create task manager
                    let taskManager = RecognitionTaskManager()

                    // Create request and start recognition
                    let request = taskManager.createRequest(configuration: configuration)
                    let resultStream = taskManager.startRecognition(
                        recognizer: recognizer, request: request)

                    // Start buffer forwarding in detached task
                    Task.detached { [taskManager] in
                        for await sendableBuffer in buffers {
                            taskManager.append(buffer: sendableBuffer.buffer)
                        }
                        taskManager.endAudio()
                    }

                    // Forward results
                    for try await result in resultStream {
                        continuation.yield(result)

                        if result.isFinal {
                            break
                        }
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - File Transcription

    /// Transcribes audio from a file URL with streaming updates.
    ///
    /// - Parameters:
    ///   - fileURL: URL of the audio file to transcribe
    ///   - configuration: The transcription configuration
    /// - Returns: Async stream of transcription results
    public func transcribeFileStream(
        fileURL: URL,
        configuration: TranscriptionConfiguration
    ) -> AsyncThrowingStream<TranscriptionResult, Error> {
        let recognizerManager = self.recognizerManager

        return AsyncThrowingStream { continuation in
            _ = Task { @Sendable in
                do {
                    // Request authorization
                    let status = await recognizerManager.requestAuthorization()
                    guard status == .authorized else {
                        continuation.finish(
                            throwing: UtteranceError.permission(.speechRecognitionNotAuthorized))
                        return
                    }

                    // Get recognizer
                    let recognizer = try await recognizerManager.getRecognizer(
                        for: configuration.locale)

                    // Create URL-based request
                    let request = SFSpeechURLRecognitionRequest(url: fileURL)
                    request.shouldReportPartialResults = true  // Enable partials for progress
                    request.taskHint = configuration.taskHint.speechTaskHint

                    if !configuration.contextualStrings.isEmpty {
                        request.contextualStrings = configuration.contextualStrings
                    }

                    if configuration.requiresOnDeviceRecognition {
                        request.requiresOnDeviceRecognition = true
                    }

                    if configuration.addsPunctuation {
                        request.addsPunctuation = true
                    }

                    // Start recognition task
                    let recognitionTask = recognizer.recognitionTask(with: request) {
                        result, error in
                        if let error = error {
                            continuation.finish(
                                throwing: UtteranceError.transcription(
                                    .recognitionFailed(reason: error.localizedDescription)
                                ))
                            return
                        }

                        guard let result = result else { return }

                        let sendable = SendableRecognitionResult(from: result)
                        continuation.yield(sendable.toTranscriptionResult())

                        if result.isFinal {
                            continuation.finish()
                        }
                    }

                    // Handle cancellation
                    continuation.onTermination = { _ in
                        recognitionTask.cancel()
                    }

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Transcribes audio from a file URL.
    ///
    /// - Parameters:
    ///   - fileURL: URL of the audio file to transcribe
    ///   - configuration: The transcription configuration
    /// - Returns: The transcription result
    /// - Throws: ``UtteranceError/transcription(_:)`` if transcription fails
    public func transcribe(
        fileURL: URL,
        configuration: TranscriptionConfiguration
    ) async throws -> TranscriptionResult {
        // Request authorization
        let status = await recognizerManager.requestAuthorization()
        guard status == .authorized else {
            throw UtteranceError.permission(.speechRecognitionNotAuthorized)
        }

        // Get recognizer
        let recognizer = try await recognizerManager.getRecognizer(for: configuration.locale)

        // Create URL-based request
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        request.taskHint = configuration.taskHint.speechTaskHint

        if !configuration.contextualStrings.isEmpty {
            request.contextualStrings = configuration.contextualStrings
        }

        if configuration.requiresOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        if configuration.addsPunctuation {
            request.addsPunctuation = true
        }

        // Perform recognition using async/await wrapper
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            recognizer.recognitionTask(with: request) { result, error in
                guard !hasResumed else { return }

                if let error = error {
                    hasResumed = true
                    continuation.resume(
                        throwing: UtteranceError.transcription(
                            .recognitionFailed(reason: error.localizedDescription)
                        ))
                    return
                }

                guard let result = result else { return }

                if result.isFinal {
                    hasResumed = true
                    let sendable = SendableRecognitionResult(from: result)
                    continuation.resume(returning: sendable.toTranscriptionResult())
                }
            }
        }
    }

    // MARK: - Status

    /// Cancels any ongoing transcription.
    public func cancel() async {
        taskManager?.cancel()
        taskManager = nil
    }

    /// Whether transcription is currently active.
    public var isTranscribing: Bool {
        taskManager?.isActive ?? false
    }

    /// Gets the list of supported locales.
    public nonisolated static var supportedLocales: Set<Locale> {
        SpeechRecognizerManager.supportedLocales
    }

    // MARK: - Private Helpers

    private func setTaskManager(_ manager: RecognitionTaskManager?) {
        self.taskManager = manager
    }
}
