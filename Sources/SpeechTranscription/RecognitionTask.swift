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
@preconcurrency import Speech

/// A Sendable wrapper for SFSpeechRecognitionResult.
public struct SendableRecognitionResult: @unchecked Sendable {
    public let text: String
    public let isFinal: Bool
    public let segments: [TranscriptionSegment]
    public let confidence: Float
    public let speakingRate: Double

    init(from result: SFSpeechRecognitionResult) {
        let transcription = result.bestTranscription
        self.text = transcription.formattedString
        self.isFinal = result.isFinal

        self.segments = transcription.segments.map { segment in
            TranscriptionSegment(
                text: segment.substring,
                timestamp: segment.timestamp,
                duration: segment.duration,
                confidence: segment.confidence
            )
        }

        if self.segments.isEmpty {
            self.confidence = 1.0
        } else {
            self.confidence =
                self.segments.reduce(0) { $0 + $1.confidence } / Float(self.segments.count)
        }

        self.speakingRate = result.speechRecognitionMetadata?.speakingRate ?? 0.0
    }

    func toTranscriptionResult() -> TranscriptionResult {
        TranscriptionResult(
            text: text,
            segments: segments,
            isFinal: isFinal,
            confidence: confidence,
            speakingRate: speakingRate
        )
    }
}

/// Manages a speech recognition task with async/await support.
///
/// This class wraps `SFSpeechRecognitionTask` to provide a modern async interface
/// for streaming recognition results.
public final class RecognitionTaskManager: @unchecked Sendable {

    // MARK: - Properties

    private var currentTask: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var resultContinuation: AsyncThrowingStream<TranscriptionResult, Error>.Continuation?
    private let lock = NSLock()

    // MARK: - Initialization

    /// Creates a new recognition task manager.
    public init() {}

    // MARK: - Task Control

    /// Creates and configures a recognition request.
    ///
    /// - Parameter configuration: The transcription configuration
    /// - Returns: The configured recognition request
    public func createRequest(
        configuration: TranscriptionConfiguration
    ) -> SFSpeechAudioBufferRecognitionRequest {
        lock.lock()
        defer { lock.unlock() }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = configuration.shouldReportPartialResults
        request.addsPunctuation = configuration.addsPunctuation
        request.taskHint = configuration.taskHint.speechTaskHint

        // Configure on-device recognition if required
        if configuration.requiresOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        // Add contextual strings for custom vocabulary
        if !configuration.contextualStrings.isEmpty {
            request.contextualStrings = configuration.contextualStrings
        }

        self.request = request
        return request
    }

    /// Starts recognition with the given recognizer and request.
    ///
    /// - Parameters:
    ///   - recognizer: The speech recognizer
    ///   - request: The recognition request
    /// - Returns: Async stream of transcription results
    public func startRecognition(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest
    ) -> AsyncThrowingStream<TranscriptionResult, Error> {
        AsyncThrowingStream { [weak self] continuation in
            self?.lock.lock()
            self?.resultContinuation = continuation
            self?.lock.unlock()

            let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                self?.handleResult(result, error: error)
            }

            self?.lock.lock()
            self?.currentTask = task
            self?.lock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.cancel()
            }
        }
    }

    /// Appends an audio buffer to the recognition request.
    ///
    /// - Parameter buffer: The audio buffer to append
    public func append(buffer: AVAudioPCMBuffer) {
        lock.lock()
        let req = request
        lock.unlock()
        req?.append(buffer)
    }

    /// Signals the end of audio input.
    public func endAudio() {
        lock.lock()
        let req = request
        lock.unlock()
        req?.endAudio()
    }

    /// Cancels the current recognition task.
    public func cancel() {
        lock.lock()
        currentTask?.cancel()
        currentTask = nil
        request = nil
        resultContinuation?.finish()
        resultContinuation = nil
        lock.unlock()
    }

    // MARK: - Status

    /// Whether a recognition task is currently active.
    public var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentTask != nil && currentTask?.state == .running
    }

    // MARK: - Private Methods

    private func handleResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        lock.lock()
        let continuation = resultContinuation
        lock.unlock()

        if let error = error {
            let utteranceError = mapError(error)
            continuation?.finish(throwing: utteranceError)
            cleanup()
            return
        }

        guard let result = result else { return }

        let sendable = SendableRecognitionResult(from: result)
        continuation?.yield(sendable.toTranscriptionResult())

        if result.isFinal {
            continuation?.finish()
            cleanup()
        }
    }

    private func mapError(_ error: Error) -> UtteranceError {
        let nsError = error as NSError

        // Check for specific Speech framework errors
        if nsError.domain == "kAFAssistantErrorDomain" {
            switch nsError.code {
            case 1110:
                return .transcription(.noSpeechDetected)
            case 1700:
                return .transcription(.quotaExceeded)
            default:
                break
            }
        }

        return .transcription(.recognitionFailed(reason: error.localizedDescription))
    }

    private func cleanup() {
        lock.lock()
        currentTask = nil
        request = nil
        resultContinuation = nil
        lock.unlock()
    }
}
