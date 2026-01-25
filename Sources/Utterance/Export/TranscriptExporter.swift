// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import Foundation

/// Utilities for exporting transcripts to various standard formats.
public struct TranscriptExporter: Sendable {

    // MARK: - Public API

    /// Exports a list of transcript items to the specified format.
    ///
    /// - Parameters:
    ///   - items: The items to export.
    ///   - format: The desired output format.
    /// - Returns: A string representation of the exported content.
    public static func export(_ items: [TranscriptItem], to format: ExportFormat) throws -> String {
        switch format {
        case .srt:
            return generateSRT(from: items)
        case .vtt:
            return generateVTT(from: items)
        case .json:
            return try generateJSON(from: items)
        case .txt:
            return generateText(from: items)
        }
    }

    // MARK: - Generators

    private static func generateSRT(from items: [TranscriptItem]) -> String {
        var output = ""

        for (index, item) in items.enumerated() {
            let sequence = index + 1
            let start = formatTimeSRT(item.timeRange.lowerBound)
            let end = formatTimeSRT(item.timeRange.upperBound)

            output += "\(sequence)\n"
            output += "\(start) --> \(end)\n"
            output += "\(item.text)\n\n"
        }

        return output
    }

    private static func generateVTT(from items: [TranscriptItem]) -> String {
        var output = "WEBVTT\n\n"

        for item in items {
            let start = formatTimeVTT(item.timeRange.lowerBound)
            let end = formatTimeVTT(item.timeRange.upperBound)

            output += "\(start) --> \(end)\n"
            output += "\(item.text)\n\n"
        }

        return output
    }

    private static func generateJSON(from items: [TranscriptItem]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(items)
        guard let string = String(data: data, encoding: .utf8) else {
            throw UtteranceError.transcription(
                .recognitionFailed(reason: "Failed to encode JSON string"))
        }
        return string
    }

    private static func generateText(from items: [TranscriptItem]) -> String {
        items.map { $0.text }.joined(separator: "\n")
    }

    // MARK: - Time Formatter

    /// Formats time for SRT: HH:mm:ss,mmm
    private static func formatTimeSRT(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let millis = Int((time * 1000).truncatingRemainder(dividingBy: 1000))

        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, millis)
    }

    /// Formats time for VTT: HH:mm:ss.mmm (or mm:ss.mmm)
    private static func formatTimeVTT(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let millis = Int((time * 1000).truncatingRemainder(dividingBy: 1000))

        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, millis)
        } else {
            return String(format: "%02d:%02d.%03d", minutes, seconds, millis)
        }
    }
}

// MARK: - Encodable Conformance for TranscriptItem

extension TranscriptItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, text, start, end, confidence, speakingRate, alternatives
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let text = try container.decode(String.self, forKey: .text)
        let start = try container.decode(TimeInterval.self, forKey: .start)
        let end = try container.decode(TimeInterval.self, forKey: .end)
        let confidence = try container.decode(Float.self, forKey: .confidence)
        let speakingRate = try container.decode(Double.self, forKey: .speakingRate)
        let alternatives = try container.decode([String].self, forKey: .alternatives)

        self.init(
            id: id, text: text, start: start, end: end, confidence: confidence,
            speakingRate: speakingRate, alternatives: alternatives)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(timeRange.lowerBound, forKey: .start)
        try container.encode(timeRange.upperBound, forKey: .end)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(speakingRate, forKey: .speakingRate)
        try container.encode(alternatives, forKey: .alternatives)
    }
}
