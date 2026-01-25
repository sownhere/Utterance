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

/// Configuration for audio recording sessions.
///
/// Use this structure to configure recording parameters such as sample rate,
/// number of channels, audio format, and output file location.
///
/// ```swift
/// let config = RecordingConfiguration(
///     sampleRate: 16000,
///     channels: 1,
///     format: .m4a,
///     outputURL: FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
/// )
/// ```
public struct RecordingConfiguration: Sendable, Hashable {
    
    // MARK: - Audio Format
    
    /// Supported audio file formats for recording.
    public enum AudioFormat: String, Sendable, CaseIterable {
        /// Waveform Audio File Format - uncompressed, high quality
        case wav
        /// MPEG-4 Audio - compressed, good quality, smaller file size
        case m4a
        /// Core Audio Format - Apple's native format
        case caf
        
        /// File extension for this format
        public var fileExtension: String { rawValue }
    }
    
    // MARK: - Properties
    
    /// Sample rate in Hz (e.g., 16000, 44100, 48000)
    public let sampleRate: Double
    
    /// Number of audio channels (1 for mono, 2 for stereo)
    public let channels: Int
    
    /// Output audio format
    public let format: AudioFormat
    
    /// URL where the recording will be saved
    /// If nil, a temporary file will be created
    public let outputURL: URL?
    
    // MARK: - Initialization
    
    /// Creates a new recording configuration.
    ///
    /// - Parameters:
    ///   - sampleRate: Sample rate in Hz. Default is 16000 (optimal for speech recognition).
    ///   - channels: Number of audio channels. Default is 1 (mono).
    ///   - format: Output audio format. Default is `.m4a`.
    ///   - outputURL: URL where the recording will be saved. If nil, a temporary file will be created.
    public init(
        sampleRate: Double = 16000,
        channels: Int = 1,
        format: AudioFormat = .m4a,
        outputURL: URL? = nil
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.format = format
        self.outputURL = outputURL
    }
}

// MARK: - Default Configurations

extension RecordingConfiguration {
    
    /// Default configuration optimized for speech recognition.
    ///
    /// - Sample rate: 16000 Hz
    /// - Channels: 1 (mono)
    /// - Format: m4a
    public static let `default` = RecordingConfiguration()
    
    /// High quality configuration for audio recording.
    ///
    /// - Sample rate: 44100 Hz
    /// - Channels: 2 (stereo)
    /// - Format: m4a
    public static let highQuality = RecordingConfiguration(
        sampleRate: 44100,
        channels: 2,
        format: .m4a
    )
    
    /// Uncompressed configuration for maximum quality.
    ///
    /// - Sample rate: 48000 Hz
    /// - Channels: 2 (stereo)
    /// - Format: wav
    public static let uncompressed = RecordingConfiguration(
        sampleRate: 48000,
        channels: 2,
        format: .wav
    )
}
