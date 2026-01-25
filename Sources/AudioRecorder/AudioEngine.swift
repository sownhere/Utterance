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

/// Manages the AVAudioEngine for audio capture.
///
/// This actor provides a safe wrapper around AVAudioEngine, handling
/// audio input tap installation and buffer streaming.
///
/// ```swift
/// let engineManager = AudioEngineManager()
/// let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
/// try await engineManager.start(format: format)
///
/// for await sendableBuffer in await engineManager.audioBufferStream {
///     let buffer = sendableBuffer.buffer
///     // Process audio buffer
/// }
///
/// await engineManager.stop()
/// ```
public actor AudioEngineManager {

    // MARK: - Properties

    private let engine: AVAudioEngine
    private var continuations: [UUID: AsyncStream<SendableAudioBuffer>.Continuation] = [:]
    private var isRunning = false

    /// The current audio format being used by the engine.
    public private(set) var currentFormat: AVAudioFormat?

    // MARK: - Initialization

    /// Creates a new audio engine manager.
    public init() {
        self.engine = AVAudioEngine()
    }

    // MARK: - Audio Buffer Stream

    /// Stream of audio buffers captured from the input node.
    ///
    /// Returns a new stream for each access. The stream will receive all
    /// audio buffers captured while the engine is running.
    public var audioBufferStream: AsyncStream<SendableAudioBuffer> {
        let id = UUID()

        return AsyncStream<SendableAudioBuffer>(bufferingPolicy: .bufferingNewest(10)) {
            continuation in
            // Register continuation
            continuations[id] = continuation

            // Handle termination
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    // MARK: - Engine Control

    /// Starts the audio engine with the specified format.
    ///
    /// - Parameter format: The desired audio format for capture
    /// - Throws: ``UtteranceError/recording(_:)`` if the engine fails to start
    public func start(format: AVAudioFormat) async throws {
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Validate input is available
        guard inputFormat.channelCount > 0 else {
            throw UtteranceError.recording(.noInputAvailable)
        }

        // Install tap on input node
        let bufferSize: AVAudioFrameCount = 1024
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) {
            [weak self] buffer, _ in
            guard let self = self else { return }

            // Wrap buffer
            let sendable = SendableAudioBuffer(buffer)

            // Broadcast to all listeners
            Task {
                await self.broadcast(sendable)
            }
        }

        // Prepare and start engine
        engine.prepare()

        do {
            try engine.start()
            isRunning = true
            currentFormat = inputFormat
        } catch {
            inputNode.removeTap(onBus: 0)
            throw UtteranceError.recording(.engineStartFailed(reason: error.localizedDescription))
        }
    }

    private func broadcast(_ buffer: SendableAudioBuffer) {
        for continuation in continuations.values {
            continuation.yield(buffer)
        }
    }

    /// Stops the audio engine.
    public func stop() async {
        guard isRunning else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()

        isRunning = false
        currentFormat = nil
    }

    /// Pauses the audio engine.
    public func pause() async {
        engine.pause()
    }

    /// Resets the audio engine.
    public func reset() async {
        await stop()
        engine.reset()
    }

    // MARK: - Status

    /// Whether the engine is currently running.
    public var engineIsRunning: Bool {
        isRunning
    }

    /// The input format from the audio input node.
    public var inputFormat: AVAudioFormat? {
        let format = engine.inputNode.outputFormat(forBus: 0)
        return format.channelCount > 0 ? format : nil
    }
}
