import AVFoundation
import Foundation

@testable import Utterance

public actor MockAudioRecorder: AudioRecording {

    public var isRecording: Bool = false
    public var shouldThrowOnStart: Bool = false
    public var shouldThrowOnStop: Bool = false

    private var bufferContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var sendableContinuation: AsyncStream<SendableAudioBuffer>.Continuation?

    public init() {}

    public var audioBufferStream: AsyncStream<AVAudioPCMBuffer> {
        AsyncStream { continuation in
            self.bufferContinuation = continuation
        }
    }

    public var sendableAudioBufferStream: AsyncStream<SendableAudioBuffer> {
        AsyncStream { continuation in
            self.sendableContinuation = continuation
        }
    }

    public func startRecording(configuration: RecordingConfiguration) async throws {
        if shouldThrowOnStart {
            throw UtteranceError.recording(.engineStartFailed(reason: "Mock failure"))
        }
        isRecording = true

        // Simulate streaming some dummy buffers
        Task {
            // Need to yield buffers to keep the stream alive if relied upon,
            // or just kept open. For integration test, just open is enough.
            // We can yield one silent buffer.
            if let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)
            {
                buffer.frameLength = 1024
                bufferContinuation?.yield(buffer)
                sendableContinuation?.yield(SendableAudioBuffer(buffer))
            }
        }
    }

    public func stopRecording() async throws -> RecordingResult {
        if !isRecording {
            throw UtteranceError.recording(
                .invalidConfiguration(reason: "No recording in progress"))
        }
        if shouldThrowOnStop {
            throw UtteranceError.recording(.cancelled)
        }

        isRecording = false
        bufferContinuation?.finish()
        bufferContinuation = nil
        sendableContinuation?.finish()
        sendableContinuation = nil

        // Return a dummy result
        return RecordingResult(
            fileURL: URL(fileURLWithPath: "/dev/null"),
            duration: 1.0,
            format: .m4a
        )
    }

    public func cancelRecording() async {
        isRecording = false
        bufferContinuation?.finish()
        bufferContinuation = nil
        sendableContinuation?.finish()
        sendableContinuation = nil
    }
}
