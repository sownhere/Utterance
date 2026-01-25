// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import Foundation
import PipelineModels

/// A distinct item in a transcript, representing a sentence or statement.
///
/// Unlike a raw stream of text, a `TranscriptItem` has a clear start and end time,
/// ensuring it maps to a specific audio segment.
public struct TranscriptItem: Sendable, Hashable, Identifiable {

    /// Unique identifier for this item.
    public let id: UUID

    /// The transcribed text (e.g. a complete sentence).
    public let text: String

    /// The time range of this item relative to the start of the session.
    public let timeRange: Range<TimeInterval>

    /// The confidence level (0.0 to 1.0).
    public let confidence: Float

    /// The speaking rate during this item (words per minute).
    public let speakingRate: Double

    /// Alternative interpretations of this item (if available).
    public let alternatives: [String]

    /// Creates a new transcript item.
    ///
    /// - Parameters:
    ///   - text: The transcribed text
    ///   - start: Start time in seconds
    ///   - end: End time in seconds
    ///   - confidence: Confidence level
    ///   - speakingRate: Words per minute
    ///   - alternatives: Alternative transcriptions
    public init(
        id: UUID = UUID(),
        text: String,
        start: TimeInterval,
        end: TimeInterval,
        confidence: Float = 1.0,
        speakingRate: Double = 0.0,
        alternatives: [String] = []
    ) {
        self.id = id
        self.text = text
        self.timeRange = start..<end
        self.confidence = confidence
        self.speakingRate = speakingRate
        self.alternatives = alternatives
    }
}
