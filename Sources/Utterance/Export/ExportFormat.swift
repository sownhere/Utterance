// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import Foundation

/// Supported formats for transcript export.
public enum ExportFormat: String, Sendable, CaseIterable {

    /// SubRip Subtitle file (.srt).
    /// Standard format for video subtitles.
    case srt

    /// Web Video Text Tracks (.vtt).
    /// Standard format for HTML5 video subtitles.
    case vtt

    /// JSON dump (.json).
    /// Full metadata including confidence scores and alternatives.
    case json

    /// Plain text (.txt).
    /// Just the text content without timing.
    case txt

    /// The recommended file extension for this format.
    public var fileExtension: String {
        return rawValue
    }

    /// The MIME type for this format.
    public var mimeType: String {
        switch self {
        case .srt: return "application/x-subrip"
        case .vtt: return "text/vtt"
        case .json: return "application/json"
        case .txt: return "text/plain"
        }
    }
}
