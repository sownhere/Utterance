// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import Foundation

// MARK: - Audio Ring Buffer

/// Thread-safe, lock-free ring buffer for real-time audio processing.
///
/// Ring buffers are essential for transferring audio data between the real-time
/// audio thread and application threads without blocking or allocations.
///
/// ## Overview
///
/// ```swift
/// let ringBuffer = AudioRingBuffer(capacity: 4096)
///
/// // Audio callback (real-time thread - no allocations!)
/// audioEngine.inputNode.installTap(...) { buffer, time in
///     buffer.floatChannelData![0].withMemoryRebound(to: Float.self, capacity: Int(buffer.frameLength)) { ptr in
///         ringBuffer.write(UnsafeBufferPointer(start: ptr, count: Int(buffer.frameLength)))
///     }
/// }
///
/// // Consumer task (non-real-time)
/// Task {
///     while !Task.isCancelled {
///         let samples = ringBuffer.read(1024)
///         await process(samples)
///     }
/// }
/// ```
///
/// ## Thread Safety
///
/// This implementation is designed for single-producer, single-consumer scenarios:
/// - **Producer:** Audio render callback (writes)
/// - **Consumer:** Application task (reads)
public final class AudioRingBuffer: @unchecked Sendable {

    // MARK: - Properties

    private let buffer: UnsafeMutablePointer<Float>
    private let capacity: Int

    /// Volatile indices for lock-free SPSC operation
    /// Using nonisolated(unsafe) for single-producer/single-consumer pattern
    private nonisolated(unsafe) var writeIndex: Int = 0
    private nonisolated(unsafe) var readIndex: Int = 0

    // MARK: - Initialization

    /// Creates a ring buffer with the specified capacity.
    ///
    /// - Parameter capacity: Maximum number of samples the buffer can hold
    public init(capacity: Int) {
        self.capacity = capacity
        self.buffer = .allocate(capacity: capacity)
        self.buffer.initialize(repeating: 0, count: capacity)
    }

    deinit {
        buffer.deallocate()
    }

    // MARK: - Write Operations

    /// Writes samples to the buffer.
    ///
    /// Designed to be called from the real-time audio thread.
    /// No allocations or locks are taken.
    ///
    /// - Parameter samples: Buffer of samples to write
    /// - Returns: Number of samples actually written (may be less if buffer full)
    @discardableResult
    @inline(__always)
    public func write(_ samples: UnsafeBufferPointer<Float>) -> Int {
        let currentWrite = writeIndex
        let currentRead = readIndex
        let available = capacity - (currentWrite - currentRead)
        let samplesToWrite = min(samples.count, available)

        guard samplesToWrite > 0, let base = samples.baseAddress else { return 0 }

        let writePos = currentWrite % capacity
        let firstChunk = min(samplesToWrite, capacity - writePos)
        let secondChunk = samplesToWrite - firstChunk

        // First chunk (up to end of buffer)
        memcpy(
            buffer.advanced(by: writePos),
            base,
            firstChunk * MemoryLayout<Float>.size
        )

        // Second chunk (wrap around to start)
        if secondChunk > 0 {
            memcpy(
                buffer,
                base.advanced(by: firstChunk),
                secondChunk * MemoryLayout<Float>.size
            )
        }

        // Memory barrier before updating write index
        writeIndex = currentWrite + samplesToWrite

        return samplesToWrite
    }

    /// Writes samples from an array.
    ///
    /// - Parameter samples: Array of samples to write
    /// - Returns: Number of samples actually written
    @discardableResult
    public func write(_ samples: [Float]) -> Int {
        samples.withUnsafeBufferPointer { write($0) }
    }

    // MARK: - Read Operations

    /// Reads samples from the buffer.
    ///
    /// - Parameter count: Maximum number of samples to read
    /// - Returns: Array of samples (may contain fewer than requested)
    public func read(_ count: Int) -> [Float] {
        let currentWrite = writeIndex
        let currentRead = readIndex
        let available = currentWrite - currentRead
        let samplesToRead = min(count, available)

        guard samplesToRead > 0 else { return [] }

        var result = [Float](repeating: 0, count: samplesToRead)

        let readPos = currentRead % capacity
        let firstChunk = min(samplesToRead, capacity - readPos)
        let secondChunk = samplesToRead - firstChunk

        result.withUnsafeMutableBufferPointer { ptr in
            memcpy(
                ptr.baseAddress!,
                buffer.advanced(by: readPos),
                firstChunk * MemoryLayout<Float>.size
            )

            if secondChunk > 0 {
                memcpy(
                    ptr.baseAddress!.advanced(by: firstChunk),
                    buffer,
                    secondChunk * MemoryLayout<Float>.size
                )
            }
        }

        // Update read index
        readIndex = currentRead + samplesToRead

        return result
    }

    /// Reads samples into a pre-allocated buffer.
    ///
    /// Use this for zero-allocation reads on performance-critical paths.
    ///
    /// - Parameters:
    ///   - destination: Pre-allocated buffer to write into
    ///   - count: Maximum samples to read
    /// - Returns: Actual number of samples read
    @discardableResult
    @inline(__always)
    public func read(into destination: UnsafeMutableBufferPointer<Float>, count: Int) -> Int {
        let currentWrite = writeIndex
        let currentRead = readIndex
        let available = currentWrite - currentRead
        let samplesToRead = min(min(count, available), destination.count)

        guard samplesToRead > 0 else { return 0 }

        let readPos = currentRead % capacity
        let firstChunk = min(samplesToRead, capacity - readPos)
        let secondChunk = samplesToRead - firstChunk

        memcpy(
            destination.baseAddress!,
            buffer.advanced(by: readPos),
            firstChunk * MemoryLayout<Float>.size
        )

        if secondChunk > 0 {
            memcpy(
                destination.baseAddress!.advanced(by: firstChunk),
                buffer,
                secondChunk * MemoryLayout<Float>.size
            )
        }

        readIndex = currentRead + samplesToRead

        return samplesToRead
    }

    // MARK: - Status

    /// Number of samples available to read.
    public var availableCount: Int {
        writeIndex - readIndex
    }

    /// Space available for writing.
    public var availableSpace: Int {
        capacity - availableCount
    }

    /// Whether the buffer is empty.
    public var isEmpty: Bool {
        writeIndex == readIndex
    }

    /// Whether the buffer is full.
    public var isFull: Bool {
        availableCount >= capacity
    }

    /// Total capacity of the buffer.
    public var bufferCapacity: Int {
        capacity
    }

    /// Clears the buffer.
    public func clear() {
        readIndex = writeIndex
    }
}

// MARK: - Typed Ring Buffer

/// Generic ring buffer for any Sendable type.
public final class RingBuffer<T: Sendable>: @unchecked Sendable {

    private let storage: UnsafeMutablePointer<T?>
    private let capacity: Int
    private var writeIndex: Int = 0
    private var readIndex: Int = 0

    public init(capacity: Int) {
        self.capacity = capacity
        self.storage = .allocate(capacity: capacity)
        self.storage.initialize(repeating: nil, count: capacity)
    }

    deinit {
        storage.deinitialize(count: capacity)
        storage.deallocate()
    }

    @discardableResult
    public func write(_ value: T) -> Bool {
        let currentCount = (writeIndex - readIndex + capacity) % capacity
        guard currentCount < capacity - 1 else { return false }

        storage[writeIndex] = value
        writeIndex = (writeIndex + 1) % capacity
        return true
    }

    public func read() -> T? {
        guard writeIndex != readIndex else { return nil }

        let value = storage[readIndex]
        storage[readIndex] = nil
        readIndex = (readIndex + 1) % capacity
        return value
    }

    public var count: Int {
        (writeIndex - readIndex + capacity) % capacity
    }

    public var isEmpty: Bool {
        writeIndex == readIndex
    }
}
