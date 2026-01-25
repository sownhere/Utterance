// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import Foundation

// MARK: - Progress Types

/// Progress information during audio recording.
public struct RecordingProgress: Sendable {

    /// Current duration of the recording in seconds.
    public let duration: TimeInterval

    /// Average audio level (0.0 to 1.0).
    public let averageLevel: Float

    /// Peak audio level (0.0 to 1.0).
    public let peakLevel: Float

    /// Current buffer count.
    public let bufferCount: Int

    public init(
        duration: TimeInterval,
        averageLevel: Float = 0,
        peakLevel: Float = 0,
        bufferCount: Int = 0
    ) {
        self.duration = duration
        self.averageLevel = averageLevel
        self.peakLevel = peakLevel
        self.bufferCount = bufferCount
    }
}

/// Progress information during speech transcription.
public struct TranscriptionProgress: Sendable {

    /// Partial transcription text (may change).
    public let partialText: String

    /// Confidence level (0.0 to 1.0).
    public let confidence: Float

    /// Whether this is the final result.
    public let isFinal: Bool

    /// Segments with timestamps (uses existing TranscriptionSegment from PipelineResult).
    public let segments: [TranscriptionSegment]

    /// Estimated speaking rate in words per minute.
    public let speakingRate: Double

    public init(
        partialText: String,
        confidence: Float = 0,
        isFinal: Bool = false,
        segments: [TranscriptionSegment] = [],
        speakingRate: Double = 0.0
    ) {
        self.partialText = partialText
        self.confidence = confidence
        self.isFinal = isFinal
        self.segments = segments
        self.speakingRate = speakingRate
    }
}

/// Progress information during translation.
public struct TranslationProgress: Sendable {

    /// Partial translation text.
    public let partialText: String

    /// Characters translated so far.
    public let characterCount: Int

    /// Total characters to translate.
    public let totalCharacters: Int

    /// Progress percentage (0.0 to 1.0).
    public var progress: Float {
        guard totalCharacters > 0 else { return 0 }
        return Float(characterCount) / Float(totalCharacters)
    }

    public init(
        partialText: String,
        characterCount: Int,
        totalCharacters: Int
    ) {
        self.partialText = partialText
        self.characterCount = characterCount
        self.totalCharacters = totalCharacters
    }
}
