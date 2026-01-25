import AVFoundation
import Foundation

/// Protocol for custom waveform processing
public protocol WaveformProvider: Sendable {
    /// Process audio buffer into visualization samples
    /// - Parameter buffer: Raw audio buffer
    /// - Returns: Normalized samples (-1.0 to 1.0) for visualization
    func process(buffer: AVAudioPCMBuffer) -> [Float]

    /// Downsample factor (how many samples to skip)
    var downsampleFactor: Int { get }

    /// Batch size for UI updates
    var batchSize: Int { get }
}

// Default implementation
extension WaveformProvider {
    public var downsampleFactor: Int { 4 }
    public var batchSize: Int { 256 }
}
