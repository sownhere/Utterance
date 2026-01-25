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

import Foundation

/// Errors that can occur during Utterance operations.
///
/// This enum provides a comprehensive set of errors organized by category:
/// - ``RecordingError``: Audio recording failures
/// - ``TranscriptionError``: Speech recognition failures
/// - ``TranslationError``: Translation failures
/// - ``PermissionError``: Permission-related failures
public enum UtteranceError: Error, Equatable {

    /// Audio recording error
    case recording(RecordingError)

    /// Speech transcription error
    case transcription(TranscriptionError)

    /// Text translation error
    case translation(TranslationError)

    /// Permission error
    case permission(PermissionError)

    // MARK: - Error Code

    /// A code that identifies the error category.
    public enum Code: Int, Sendable, Equatable {
        case recordingFailed
        case transcriptionFailed
        case translationFailed
        case permissionDenied

        // Detailed codes
        case audioSessionSetupFailed
        case engineStartFailed
        case fileWriteFailed
        case invalidConfiguration
        case internalError
        case serviceUnavailable
        case timeout
    }

    /// The error code.
    public var code: Code {
        switch self {
        case .recording(let error):
            return error.code
        case .transcription(let error):
            return error.code
        case .translation(let error):
            return error.code
        case .permission(let error):
            return error.code
        }
    }

    // MARK: - Recording Errors

    /// Errors that occur during audio recording.
    public enum RecordingError: Error, Sendable, Equatable {

        /// Failed to configure the audio session
        case audioSessionSetupFailed(reason: String)

        /// Failed to start the audio engine
        case engineStartFailed(reason: String)

        /// Failed to write audio to file
        case fileWriteFailed(url: URL, reason: String)

        /// Invalid recording configuration
        case invalidConfiguration(reason: String)

        /// Recording was cancelled
        case cancelled

        /// No audio input available
        case noInputAvailable
    }

    // MARK: - Transcription Errors

    /// Errors that occur during speech transcription.
    public enum TranscriptionError: Error, Sendable, Equatable {

        /// Speech recognizer is not available for the specified locale
        case recognizerUnavailable(locale: String)

        /// Speech recognition failed
        case recognitionFailed(reason: String)

        /// No speech was detected in the audio
        case noSpeechDetected

        /// Recognition quota exceeded
        case quotaExceeded

        /// Recognition task was cancelled
        case cancelled

        /// Invalid audio format for recognition
        case invalidAudioFormat(reason: String)
    }

    // MARK: - Translation Errors

    /// Errors that occur during text translation.
    public enum TranslationError: Error, Sendable, Equatable {

        /// Language is not supported for translation
        case languageUnsupported(language: String)

        /// Translation failed
        case translationFailed(reason: String)

        /// Language model is not downloaded
        case modelNotDownloaded(from: String, to: String)

        /// Translation service is unavailable
        case serviceUnavailable

        /// Empty text provided for translation
        case emptyText
    }

    // MARK: - Permission Errors

    /// Errors related to missing permissions.
    public enum PermissionError: Error, Sendable, Equatable {

        /// Microphone access not authorized
        case microphoneNotAuthorized

        /// Speech recognition not authorized
        case speechRecognitionNotAuthorized

        /// Permission was denied by user
        case denied(permission: String)

        /// Permission status is restricted
        case restricted(permission: String)

        public var code: UtteranceError.Code {
            switch self {
            case .microphoneNotAuthorized, .speechRecognitionNotAuthorized, .denied, .restricted:
                return .permissionDenied
            }
        }
    }
}

extension UtteranceError.RecordingError {
    public var code: UtteranceError.Code {
        switch self {
        case .audioSessionSetupFailed: return .audioSessionSetupFailed
        case .engineStartFailed: return .engineStartFailed
        case .fileWriteFailed: return .fileWriteFailed
        case .invalidConfiguration: return .invalidConfiguration
        case .cancelled, .noInputAvailable: return .recordingFailed
        }
    }
}

extension UtteranceError.TranscriptionError {
    public var code: UtteranceError.Code {
        switch self {
        case .recognizerUnavailable, .recognitionFailed, .noSpeechDetected, .quotaExceeded,
            .cancelled, .invalidAudioFormat:
            return .transcriptionFailed
        }
    }
}

extension UtteranceError.TranslationError {
    public var code: UtteranceError.Code {
        switch self {
        case .serviceUnavailable: return .serviceUnavailable
        default: return .translationFailed
        }
    }
}

// MARK: - LocalizedError Conformance

extension UtteranceError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .recording(let error):
            return "Recording Error: \(error.localizedDescription)"
        case .transcription(let error):
            return "Transcription Error: \(error.localizedDescription)"
        case .translation(let error):
            return "Translation Error: \(error.localizedDescription)"
        case .permission(let error):
            return "Permission Error: \(error.localizedDescription)"
        }
    }
}

extension UtteranceError.RecordingError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .audioSessionSetupFailed(let reason):
            return "Failed to setup audio session: \(reason)"
        case .engineStartFailed(let reason):
            return "Failed to start audio engine: \(reason)"
        case .fileWriteFailed(let url, let reason):
            return "Failed to write to \(url.lastPathComponent): \(reason)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .cancelled:
            return "Recording was cancelled"
        case .noInputAvailable:
            return "No audio input available"
        }
    }
}

extension UtteranceError.TranscriptionError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .recognizerUnavailable(let locale):
            return "Speech recognizer unavailable for locale: \(locale)"
        case .recognitionFailed(let reason):
            return "Recognition failed: \(reason)"
        case .noSpeechDetected:
            return "No speech detected in audio"
        case .quotaExceeded:
            return "Speech recognition quota exceeded"
        case .cancelled:
            return "Recognition was cancelled"
        case .invalidAudioFormat(let reason):
            return "Invalid audio format: \(reason)"
        }
    }
}

extension UtteranceError.TranslationError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .languageUnsupported(let language):
            return "Language not supported: \(language)"
        case .translationFailed(let reason):
            return "Translation failed: \(reason)"
        case .modelNotDownloaded(let from, let to):
            return "Language model not downloaded for \(from) to \(to)"
        case .serviceUnavailable:
            return "Translation service unavailable"
        case .emptyText:
            return "Cannot translate empty text"
        }
    }
}

extension UtteranceError.PermissionError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .microphoneNotAuthorized:
            return "Microphone access not authorized"
        case .speechRecognitionNotAuthorized:
            return "Speech recognition not authorized"
        case .denied(let permission):
            return "\(permission) permission denied"
        case .restricted(let permission):
            return "\(permission) permission restricted"
        }
    }
}
