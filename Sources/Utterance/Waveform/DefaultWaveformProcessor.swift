import AVFoundation
import Accelerate
import Foundation

/// Default waveform processor with RMS levels
public struct DefaultWaveformProcessor: WaveformProvider {
    public let downsampleFactor: Int
    public let batchSize: Int
    public let useRMS: Bool  // Root Mean Square vs Peak

    public init(
        downsampleFactor: Int = 4,
        batchSize: Int = 256,
        useRMS: Bool = true
    ) {
        self.downsampleFactor = downsampleFactor
        self.batchSize = batchSize
        self.useRMS = useRMS
    }

    public func process(buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let frameLength = Int(buffer.frameLength)
        let samples = UnsafeBufferPointer(start: channelData[0], count: frameLength)

        // Downsample
        var result = [Float]()
        let capacity = frameLength / downsampleFactor
        result.reserveCapacity(capacity)

        // Fast path: if downsampleFactor is 1 and not using RMS, just copy
        if downsampleFactor == 1 && !useRMS {
            return Array(samples)
        }

        for i in stride(from: 0, to: samples.count, by: downsampleFactor) {
            let end = min(i + downsampleFactor, samples.count)
            let chunkCount = end - i

            if chunkCount == 0 { continue }

            if useRMS {
                // RMS of chunk
                // Use Accelerate for performance if possible, but simple loop for now
                var sumSq: Float = 0
                for j in i..<end {
                    let sample = samples[j]
                    sumSq += sample * sample
                }
                let rms = sqrt(sumSq / Float(chunkCount))
                result.append(rms)
            } else {
                // Peak value
                var peak: Float = 0
                for j in i..<end {
                    let absSample = abs(samples[j])
                    if absSample > peak {
                        peak = absSample
                    }
                }
                result.append(peak)
            }
        }

        return result
    }
}
