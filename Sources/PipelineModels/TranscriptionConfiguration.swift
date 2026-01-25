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

#if canImport(Speech)
    import Speech
#endif

/// Configuration for speech transcription sessions.
///
/// Use this structure to configure transcription parameters such as locale,
/// task hints, and on-device recognition requirements.
///
/// ```swift
/// let config = TranscriptionConfiguration(
///     locale: Locale(identifier: "en-US"),
///     taskHint: .dictation,
///     contextualStrings: ["Utterance", "SwiftUI"],
///     requiresOnDeviceRecognition: false
/// )
/// ```
public struct TranscriptionConfiguration: Sendable, Hashable {

    // MARK: - Task Hint

    /// Hints about the type of speech recognition task.
    public enum TaskHint: Int, Sendable, CaseIterable {
        /// General purpose recognition
        case unspecified = 0
        /// Dictation-style input
        case dictation = 1
        /// Search queries
        case search = 2
        /// Voice commands or confirmations
        case confirmation = 3
    }

    // MARK: - Properties

    /// The locale for speech recognition (e.g., "en-US", "vi-VN")
    public let locale: Locale

    /// Hint about the type of speech task
    public let taskHint: TaskHint

    /// Custom vocabulary words to improve recognition accuracy
    public let contextualStrings: [String]

    /// Whether to require on-device recognition (no network requests)
    public let requiresOnDeviceRecognition: Bool

    /// Whether to automatically add punctuation to recognition results
    public let addsPunctuation: Bool

    /// Whether to report partial (streaming) results
    public let shouldReportPartialResults: Bool

    // MARK: - Initialization

    /// Creates a new transcription configuration.
    ///
    /// - Parameters:
    ///   - locale: The locale for speech recognition. Default is the current locale.
    ///   - taskHint: Hint about the type of speech task. Default is `.dictation`.
    ///   - contextualStrings: Custom vocabulary words. Default is empty.
    ///   - requiresOnDeviceRecognition: Whether to require on-device recognition. Default is `false`.
    ///   - addsPunctuation: Whether to add punctuation. Default is `true`.
    ///   - shouldReportPartialResults: Whether to report partial results. Default is `true`.
    public init(
        locale: Locale = .current,
        taskHint: TaskHint = .dictation,
        contextualStrings: [String] = [],
        requiresOnDeviceRecognition: Bool = false,
        addsPunctuation: Bool = true,
        shouldReportPartialResults: Bool = true
    ) {
        self.locale = locale
        self.taskHint = taskHint
        self.contextualStrings = contextualStrings
        self.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        self.addsPunctuation = addsPunctuation
        self.shouldReportPartialResults = shouldReportPartialResults
    }
}

// MARK: - Default Configurations

extension TranscriptionConfiguration {

    /// Default configuration using the current system locale.
    public static let `default` = TranscriptionConfiguration()

    /// English (US) configuration for dictation.
    public static let english = TranscriptionConfiguration(
        locale: Locale(identifier: "en-US"),
        taskHint: .dictation
    )

    /// Vietnamese configuration for dictation.
    public static let vietnamese = TranscriptionConfiguration(
        locale: Locale(identifier: "vi-VN"),
        taskHint: .dictation
    )

    /// Japanese configuration for dictation.
    public static let japanese = TranscriptionConfiguration(
        locale: Locale(identifier: "ja-JP"),
        taskHint: .dictation
    )

    /// Chinese (Simplified) configuration for dictation.
    public static let chineseSimplified = TranscriptionConfiguration(
        locale: Locale(identifier: "zh-CN"),
        taskHint: .dictation
    )

    /// Korean configuration for dictation.
    public static let korean = TranscriptionConfiguration(
        locale: Locale(identifier: "ko-KR"),
        taskHint: .dictation
    )
}

// MARK: - Speech Framework Integration

#if canImport(Speech)
    extension TranscriptionConfiguration.TaskHint {
        /// Converts to `SFSpeechRecognitionTaskHint`
        public var speechTaskHint: SFSpeechRecognitionTaskHint {
            SFSpeechRecognitionTaskHint(rawValue: rawValue) ?? .unspecified
        }
    }
#endif
