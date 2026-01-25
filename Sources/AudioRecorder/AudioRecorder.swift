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
import PipelineModels

/// Main audio recorder implementing the ``AudioRecording`` protocol.
///
/// The `Recorder` actor provides a high-level interface for audio recording,
/// combining audio session management, engine control, and file writing.
///
/// ## Overview
///
/// Use `Recorder` to capture audio from the device's microphone. The recorder
/// provides both file output and streaming audio buffers for real-time processing.
///
/// ```swift
/// let recorder = Recorder()
///
/// // Start recording
/// try await recorder.startRecording(configuration: .default)
///
/// // Access streaming buffers for real-time processing
/// Task {
///     for await sendableBuffer in await recorder.audioBufferStream {
///         let buffer = sendableBuffer.buffer
///         // Process buffer (e.g., for speech recognition)
///     }
/// }
///
/// // Stop recording and get result
/// let result = try await recorder.stopRecording()
/// print("Recorded to: \(result.fileURL)")
/// ```
///
/// ## File Output
///
/// By default, recordings are saved to a temporary location. Specify a custom
/// output URL in the configuration to save to a specific location:
///
/// ```swift
/// let config = RecordingConfiguration(
///     sampleRate: 16000,
///     channels: 1,
///     format: .m4a,
///     outputURL: documentsDirectory.appendingPathComponent("my_recording.m4a")
/// )
/// try await recorder.startRecording(configuration: config)
/// ```
public actor Recorder: AudioRecording {

    // MARK: - Properties

    private let sessionManager: AudioSessionManager
    private let engineManager: AudioEngineManager
    private let fileRecorder: FileRecorder

    private var currentConfiguration: RecordingConfiguration?
    private var _isRecording = false
    private var recordingTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new recorder with the default session manager.
    public init() {
        self.sessionManager = AudioSessionManager.shared
        self.engineManager = AudioEngineManager()
        self.fileRecorder = FileRecorder()
    }

    /// Creates a new recorder with a custom session manager.
    ///
    /// - Parameter sessionManager: The audio session manager to use
    public init(sessionManager: AudioSessionManager) {
        self.sessionManager = sessionManager
        self.engineManager = AudioEngineManager()
        self.fileRecorder = FileRecorder()
    }

    // MARK: - AudioRecording Protocol

    /// Stream of audio buffers captured during recording.
    ///
    /// Use this stream to access raw audio data for real-time processing
    /// such as speech recognition.
    public var audioBufferStream: AsyncStream<AVAudioPCMBuffer> {
        get async {
            // Map SendableAudioBuffer back to AVAudioPCMBuffer
            let sendableStream = await engineManager.audioBufferStream
            return AsyncStream { continuation in
                Task {
                    for await sendable in sendableStream {
                        continuation.yield(sendable.buffer)
                    }
                    continuation.finish()
                }
            }
        }
    }

    /// Stream of sendable audio buffers.
    ///
    /// Use this for actor-crossing stream consumption.
    public var sendableAudioBufferStream: AsyncStream<SendableAudioBuffer> {
        get async {
            await engineManager.audioBufferStream
        }
    }

    /// Whether recording is currently in progress.
    public var isRecording: Bool {
        _isRecording
    }

    /// Starts recording audio with the specified configuration.
    ///
    /// This method:
    /// 1. Requests microphone permission if needed
    /// 2. Configures the audio session
    /// 3. Starts the audio engine
    /// 4. Begins writing to file (if output URL is specified)
    ///
    /// - Parameter configuration: The recording configuration
    /// - Throws: ``UtteranceError/permission(_:)`` if microphone access is denied
    /// - Throws: ``UtteranceError/recording(_:)`` if recording fails to start
    public func startRecording(configuration: RecordingConfiguration) async throws {
        guard !_isRecording else { return }

        // Request permission
        let hasPermission = await sessionManager.requestMicrophonePermission()
        guard hasPermission else {
            throw UtteranceError.permission(.microphoneNotAuthorized)
        }

        // Configure audio session
        try await sessionManager.configure(for: .recording)

        // Determine output URL
        let outputURL =
            configuration.outputURL ?? generateDefaultOutputURL(format: configuration.format)

        // Get the audio format from the engine
        guard let inputFormat = await engineManager.inputFormat else {
            throw UtteranceError.recording(.noInputAvailable)
        }

        // Start file recording
        try await fileRecorder.startWriting(
            to: outputURL,
            format: inputFormat,
            fileFormat: configuration.format
        )

        // Start audio engine
        try await engineManager.start(format: inputFormat)

        // Start writing buffers to file
        let bufferStream = await engineManager.audioBufferStream
        recordingTask = Task {
            for await sendableBuffer in bufferStream {
                try? await fileRecorder.write(buffer: sendableBuffer.buffer)
            }
        }

        currentConfiguration = configuration
        _isRecording = true
    }

    /// Stops the current recording and returns the result.
    ///
    /// - Returns: The recording result containing file URL and duration
    /// - Throws: ``UtteranceError/recording(_:)`` if no recording is in progress
    public func stopRecording() async throws -> RecordingResult {
        guard _isRecording else {
            throw UtteranceError.recording(
                .invalidConfiguration(reason: "No recording in progress")
            )
        }

        // Stop recording task
        recordingTask?.cancel()
        recordingTask = nil

        // Stop engine
        await engineManager.stop()

        // Finish file writing
        let result = try await fileRecorder.finishWriting()

        // Deactivate session
        try? await sessionManager.deactivate()

        // Reset state
        currentConfiguration = nil
        _isRecording = false

        return result
    }

    /// Cancels the current recording without saving.
    public func cancelRecording() async {
        recordingTask?.cancel()
        recordingTask = nil

        await engineManager.stop()
        await fileRecorder.cancel()
        try? await sessionManager.deactivate()

        currentConfiguration = nil
        _isRecording = false
    }

    // MARK: - Private Methods

    private func generateDefaultOutputURL(format: RecordingConfiguration.AudioFormat) -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "recording_\(timestamp).\(format.fileExtension)"

        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}

// MARK: - Re-exports

/// Re-export types for convenience
public typealias AudioSessionMode = AudioSessionManager.Mode
