import AVFoundation
import XCTest

@testable import Utterance

final class WaveformProcessorTests: XCTestCase {

    func testDefaultProcessorDownsamples() {
        let processor = DefaultWaveformProcessor(downsampleFactor: 4, useRMS: true)
        let buffer = createMockBuffer(samples: 100)

        let result = processor.process(buffer: buffer)

        // 100 samples / 4 = 25
        XCTAssertEqual(result.count, 25)
    }

    func testRMSCalculation() {
        let processor = DefaultWaveformProcessor(downsampleFactor: 1, useRMS: true)
        let samples: [Float] = [0.5, 0.5, 0.5, 0.5]
        let buffer = createMockBuffer(from: samples)

        // RMS of [0.5, 0.5...] is 0.5
        // sqrt((0.25 + 0.25 + 0.25 + 0.25) / 4) = sqrt(1.0/4) = sqrt(0.25) = 0.5
        let result = processor.process(buffer: buffer)

        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0], 0.5, accuracy: 0.001)
    }

    // Helper to create a dummy buffer
    private func createMockBuffer(samples count: Int) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(count))!
        buffer.frameLength = UInt32(count)
        return buffer
    }

    private func createMockBuffer(from data: [Float]) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(data.count))!
        buffer.frameLength = UInt32(data.count)

        if let floatChannelData = buffer.floatChannelData {
            for (i, sample) in data.enumerated() {
                floatChannelData[0][i] = sample
            }
        }

        return buffer
    }
}
