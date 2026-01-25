// The MIT License (MIT)
// Copyright (c) 2024 Utterance

@preconcurrency import AVFoundation

/// A Sendable wrapper for AVAudioPCMBuffer.
///
/// Since AVAudioPCMBuffer is not Sendable, this wrapper uses @unchecked Sendable
/// to allow passing buffers between actors. The caller is responsible for ensuring
/// thread-safe access to the underlying buffer.
public struct SendableAudioBuffer: @unchecked Sendable {
    /// The wrapped audio buffer.
    public let buffer: AVAudioPCMBuffer

    /// Creates a new sendable audio buffer wrapper.
    public init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
}
