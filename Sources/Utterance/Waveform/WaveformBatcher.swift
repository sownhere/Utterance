// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import Foundation

// MARK: - Waveform Batcher

/// Accumulates audio samples and emits them in batches for UI performance.
///
/// Processing every audio buffer individually can overwhelm the UI with too many
/// updates. WaveformBatcher collects samples and delivers them in larger batches
/// at a configurable rate.
///
/// ## Overview
///
/// ```swift
/// let batcher = WaveformBatcher(batchSize: 512, downsampleFactor: 4)
///
/// await batcher.setCallback { samples in
///     waveformView.update(with: samples)
/// }
///
/// // In audio processing loop
/// for await buffer in audioStream {
///     await batcher.process(buffer.samples)
/// }
/// ```
///
/// ## Performance
///
/// With a `downsampleFactor` of 4 and 44.1kHz audio:
/// - Input: ~10,000 samples/buffer
/// - After downsampling: ~2,500 samples/buffer
/// - With batchSize of 1024: ~40 UI updates/second
public actor WaveformBatcher {

    // MARK: - Properties

    /// Target batch size before emitting
    private let batchSize: Int

    /// Factor to reduce sample count (take every Nth sample)
    private let downsampleFactor: Int

    /// Accumulated samples waiting to be emitted
    private var accumulator: [Float] = []

    /// Callback to receive batched samples
    private var callback: (@Sendable ([Float]) -> Void)?

    // MARK: - Initialization

    /// Creates a new waveform batcher.
    ///
    /// - Parameters:
    ///   - batchSize: Target number of samples per batch (default: 1024)
    ///   - downsampleFactor: Take every Nth sample (default: 4)
    public init(batchSize: Int = 1024, downsampleFactor: Int = 4) {
        self.batchSize = batchSize
        self.downsampleFactor = downsampleFactor
        self.accumulator.reserveCapacity(batchSize * 2)
    }

    // MARK: - Configuration

    /// Sets the callback to receive batched samples.
    ///
    /// The callback is invoked on the MainActor to be safe for UI updates.
    public func setCallback(_ callback: @escaping @Sendable ([Float]) -> Void) {
        self.callback = callback
    }

    /// Removes the callback.
    public func clearCallback() {
        self.callback = nil
    }

    // MARK: - Processing

    /// Processes incoming samples, downsampling and batching as needed.
    ///
    /// - Parameter samples: Raw audio samples from the audio buffer
    public func process(_ samples: [Float]) {
        guard callback != nil else { return }

        // Downsample: take every Nth sample
        let downsampled: [Float]
        if downsampleFactor > 1 {
            downsampled = stride(from: 0, to: samples.count, by: downsampleFactor)
                .map { samples[$0] }
        } else {
            downsampled = samples
        }

        accumulator.append(contentsOf: downsampled)

        // Emit batches when we have enough
        while accumulator.count >= batchSize {
            let batch = Array(accumulator.prefix(batchSize))
            accumulator.removeFirst(batchSize)
            emitBatch(batch)
        }
    }

    /// Processes samples from an unsafe buffer pointer (zero-copy from audio thread).
    public func process(_ samples: UnsafeBufferPointer<Float>) {
        guard callback != nil else { return }

        // Downsample efficiently
        let count = samples.count / downsampleFactor
        var downsampled = [Float]()
        downsampled.reserveCapacity(count)

        for i in stride(from: 0, to: samples.count, by: downsampleFactor) {
            downsampled.append(samples[i])
        }

        accumulator.append(contentsOf: downsampled)

        while accumulator.count >= batchSize {
            let batch = Array(accumulator.prefix(batchSize))
            accumulator.removeFirst(batchSize)
            emitBatch(batch)
        }
    }

    /// Flushes any remaining accumulated samples.
    public func flush() {
        guard !accumulator.isEmpty, callback != nil else { return }
        let remaining = accumulator
        accumulator.removeAll(keepingCapacity: true)
        emitBatch(remaining)
    }

    /// Clears accumulated samples without emitting.
    public func clear() {
        accumulator.removeAll(keepingCapacity: true)
    }

    // MARK: - Private

    private func emitBatch(_ batch: [Float]) {
        guard let callback = callback else { return }

        Task { @MainActor in
            callback(batch)
        }
    }
}

// MARK: - Peak Detector

/// Efficiently detects peak levels for visualization.
public struct PeakDetector: Sendable {

    /// Detects peak absolute value in a sample array.
    @inline(__always)
    public static func peak(in samples: [Float]) -> Float {
        samples.reduce(0) { max($0, abs($1)) }
    }

    /// Detects peak from unsafe buffer (faster, no copy).
    @inline(__always)
    public static func peak(in samples: UnsafeBufferPointer<Float>) -> Float {
        var peak: Float = 0
        for i in 0..<samples.count {
            peak = max(peak, abs(samples[i]))
        }
        return peak
    }

    /// Computes RMS (root mean square) level.
    @inline(__always)
    public static func rms(in samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }

    /// Converts linear amplitude to decibels.
    @inline(__always)
    public static func toDecibels(_ amplitude: Float, reference: Float = 1.0) -> Float {
        guard amplitude > 0 else { return -.infinity }
        return 20 * log10(amplitude / reference)
    }
}
