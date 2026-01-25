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

// MARK: - Recording Result

/// Result of a recording session.
///
/// Contains information about the recorded audio file including its location,
/// duration, and format.
public struct RecordingResult: Sendable, Hashable {
    
    /// URL of the recorded audio file
    public let fileURL: URL
    
    /// Duration of the recording in seconds
    public let duration: TimeInterval
    
    /// Format of the recorded audio
    public let format: RecordingConfiguration.AudioFormat
    
    /// Creates a new recording result.
    ///
    /// - Parameters:
    ///   - fileURL: URL of the recorded audio file
    ///   - duration: Duration of the recording in seconds
    ///   - format: Format of the recorded audio
    public init(fileURL: URL, duration: TimeInterval, format: RecordingConfiguration.AudioFormat) {
        self.fileURL = fileURL
        self.duration = duration
        self.format = format
    }
}

// MARK: - Transcription Result

/// Result of a transcription operation.
///
/// Contains the transcribed text along with detailed segment information
/// and confidence levels.
public struct TranscriptionResult: Sendable, Hashable {
    
    /// The complete transcribed text
    public let text: String
    
    /// Individual segments with timing information
    public let segments: [TranscriptionSegment]
    
    /// Whether this is the final result (no more updates expected)
    public let isFinal: Bool
    
    /// Overall confidence level (0.0 to 1.0)
    public let confidence: Float
    
    /// Creates a new transcription result.
    ///
    /// - Parameters:
    ///   - text: The complete transcribed text
    ///   - segments: Individual segments with timing information
    ///   - isFinal: Whether this is the final result
    ///   - confidence: Overall confidence level
    public init(
        text: String,
        segments: [TranscriptionSegment] = [],
        isFinal: Bool = true,
        confidence: Float = 1.0
    ) {
        self.text = text
        self.segments = segments
        self.isFinal = isFinal
        self.confidence = confidence
    }
}

/// A segment of transcribed speech with timing information.
public struct TranscriptionSegment: Sendable, Hashable {
    
    /// The transcribed text for this segment
    public let text: String
    
    /// Start time of this segment in seconds from the beginning
    public let timestamp: TimeInterval
    
    /// Duration of this segment in seconds
    public let duration: TimeInterval
    
    /// Confidence level for this segment (0.0 to 1.0)
    public let confidence: Float
    
    /// Creates a new transcription segment.
    ///
    /// - Parameters:
    ///   - text: The transcribed text for this segment
    ///   - timestamp: Start time of this segment in seconds
    ///   - duration: Duration of this segment in seconds
    ///   - confidence: Confidence level for this segment
    public init(
        text: String,
        timestamp: TimeInterval,
        duration: TimeInterval,
        confidence: Float = 1.0
    ) {
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.confidence = confidence
    }
}

// MARK: - Translation Result

/// Result of a translation operation.
///
/// Contains the original and translated text along with language information.
public struct TranslationResult: Sendable, Hashable {
    
    /// The original text before translation
    public let originalText: String
    
    /// The translated text
    public let translatedText: String
    
    /// The source language
    public let sourceLanguage: Locale.Language
    
    /// The target language
    public let targetLanguage: Locale.Language
    
    /// Creates a new translation result.
    ///
    /// - Parameters:
    ///   - originalText: The original text before translation
    ///   - translatedText: The translated text
    ///   - sourceLanguage: The source language
    ///   - targetLanguage: The target language
    public init(
        originalText: String,
        translatedText: String,
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

// MARK: - Pipeline Result

/// Combined result from the full speech pipeline.
///
/// Contains results from recording, transcription, and optionally translation.
public struct PipelineResult: Sendable {
    
    /// The recording result (if recording was performed)
    public let recording: RecordingResult?
    
    /// The transcription result
    public let transcription: TranscriptionResult
    
    /// The translation result (if translation was performed)
    public let translation: TranslationResult?
    
    /// Creates a new pipeline result.
    ///
    /// - Parameters:
    ///   - recording: The recording result
    ///   - transcription: The transcription result
    ///   - translation: The translation result
    public init(
        recording: RecordingResult? = nil,
        transcription: TranscriptionResult,
        translation: TranslationResult? = nil
    ) {
        self.recording = recording
        self.transcription = transcription
        self.translation = translation
    }
}
