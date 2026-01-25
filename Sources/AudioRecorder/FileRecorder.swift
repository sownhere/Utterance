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

import AVFoundation
import Foundation
import PipelineModels

/// Handles writing audio buffers to file.
///
/// This actor manages the audio file writing process, providing a safe
/// interface for writing capture buffers to disk.
///
/// ```swift
/// let fileRecorder = FileRecorder()
/// let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
/// try await fileRecorder.startWriting(to: outputURL, format: audioFormat, fileFormat: .m4a)
///
/// // Write buffers as they come
/// for await buffer in audioBufferStream {
///     try await fileRecorder.write(buffer: buffer)
/// }
///
/// let result = try await fileRecorder.finishWriting()
/// ```
public actor FileRecorder {
    
    // MARK: - Properties
    
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    private var startTime: Date?
    private var fileFormat: RecordingConfiguration.AudioFormat = .m4a
    private var framesWritten: AVAudioFrameCount = 0
    private var sampleRate: Double = 16000
    
    // MARK: - Initialization
    
    /// Creates a new file recorder.
    public init() {}
    
    // MARK: - Recording Control
    
    /// Starts writing audio to the specified file.
    ///
    /// - Parameters:
    ///   - url: The output file URL
    ///   - format: The audio format for the buffers
    ///   - fileFormat: The desired output file format
    /// - Throws: ``UtteranceError/recording(_:)`` if file creation fails
    public func startWriting(
        to url: URL,
        format: AVAudioFormat,
        fileFormat: RecordingConfiguration.AudioFormat
    ) async throws {
        // Ensure directory exists
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Convert file format to audio file type
        let audioFileType = fileType(for: fileFormat)
        
        do {
            audioFile = try AVAudioFile(
                forWriting: url,
                settings: format.settings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
            
            outputURL = url
            self.fileFormat = fileFormat
            self.sampleRate = format.sampleRate
            startTime = Date()
            framesWritten = 0
        } catch {
            throw UtteranceError.recording(
                .fileWriteFailed(url: url, reason: error.localizedDescription)
            )
        }
    }
    
    /// Writes an audio buffer to the file.
    ///
    /// - Parameter buffer: The audio buffer to write
    /// - Throws: ``UtteranceError/recording(_:)`` if writing fails
    public func write(buffer: AVAudioPCMBuffer) async throws {
        guard let file = audioFile else {
            throw UtteranceError.recording(
                .invalidConfiguration(reason: "File recorder not started")
            )
        }
        
        do {
            try file.write(from: buffer)
            framesWritten += buffer.frameLength
        } catch {
            throw UtteranceError.recording(
                .fileWriteFailed(url: outputURL ?? URL(fileURLWithPath: "/"), reason: error.localizedDescription)
            )
        }
    }
    
    /// Finishes writing and closes the file.
    ///
    /// - Returns: The recording result with file information
    /// - Throws: ``UtteranceError/recording(_:)`` if finishing fails
    public func finishWriting() async throws -> RecordingResult {
        guard let url = outputURL else {
            throw UtteranceError.recording(
                .invalidConfiguration(reason: "File recorder not started")
            )
        }
        
        // Calculate duration
        let duration: TimeInterval
        if let start = startTime {
            duration = Date().timeIntervalSince(start)
        } else {
            duration = Double(framesWritten) / sampleRate
        }
        
        // Close the file
        audioFile = nil
        
        let result = RecordingResult(
            fileURL: url,
            duration: duration,
            format: fileFormat
        )
        
        // Reset state
        outputURL = nil
        startTime = nil
        framesWritten = 0
        
        return result
    }
    
    /// Cancels the current recording and deletes the file.
    public func cancel() async {
        audioFile = nil
        
        if let url = outputURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        outputURL = nil
        startTime = nil
        framesWritten = 0
    }
    
    // MARK: - Status
    
    /// Whether the file recorder is currently recording.
    public var isRecording: Bool {
        audioFile != nil
    }
    
    /// The current recording duration in seconds.
    public var currentDuration: TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    // MARK: - Private Methods
    
    private func fileType(for format: RecordingConfiguration.AudioFormat) -> AudioFileTypeID {
        switch format {
        case .wav:
            return kAudioFileWAVEType
        case .m4a:
            return kAudioFileM4AType
        case .caf:
            return kAudioFileCAFType
        }
    }
}
