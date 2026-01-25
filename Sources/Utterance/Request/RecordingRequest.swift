// The MIT License (MIT)
// Copyright (c) 2024 Utterance

@preconcurrency import AVFoundation
import AudioRecorder
import Foundation
import PipelineModels
import SpeechTranscription
import os

// MARK: - Recording Request

/// A request for audio recording operations.
/// ...
public final class RecordingRequest: @unchecked Sendable {

    // MARK: - Properties

    /// Unique identifier for this request
    public let id: RequestID

    /// Lock for thread-safe access to mutable properties
    private let lock = OSAllocatedUnfairLock()

    /// The recording configuration
    public let configuration: RecordingConfiguration

    /// Current state (thread-safe access via actor)
    private let stateActor = StateActor()

    /// The underlying recorder
    private let recorder: any AudioRecording

    /// Start time for duration tracking
    private var startTime: Date?

    // MARK: - Handlers

    private var waveformHandler: (@Sendable ([Float]) -> Void)?
    private var waveformProvider: (any WaveformProvider)?
    private var liveTranscriptionHandler: (@Sendable (TranscriptionResult) -> Void)?
    private var liveTranscriptionConfiguration: TranscriptionConfiguration?
    private var progressHandler: (@Sendable (RecordingProgress) -> Void)?
    private var willStartHandler: VoidHandler?
    private var didCompleteHandler: (@Sendable (RecordingResult) -> Void)?
    private var didFailHandler: ErrorHandler?
    private var responseCompletion: (@Sendable (Result<RecordingResult, UtteranceError>) -> Void)?
    private var responseQueue: DispatchQueue = .main

    // MARK: - Interceptors

    private var requestInterceptors: [any PipelineInterceptor] = []

    // MARK: - Internal State Actor

    private actor StateActor {
        var state: RequestState = .initialized
        var retryCount: Int = 0

        func setState(_ newState: RequestState) {
            state = newState
        }

        func incrementRetry() -> Int {
            retryCount += 1
            return retryCount
        }
    }

    // MARK: - Initialization

    /// Creates a new recording request.
    ///
    /// - Parameters:
    ///   - configuration: The recording configuration
    ///   - recorder: The recorder instance to use
    public init(
        configuration: RecordingConfiguration,
        recorder: any AudioRecording = Recorder()
    ) {
        self.id = RequestID()
        self.configuration = configuration
        self.recorder = recorder
    }

    // MARK: - State Access

    /// Current state of the request
    public var state: RequestState {
        get async {
            await stateActor.state
        }
    }

    /// Number of retry attempts
    public var retryCount: Int {
        get async {
            await stateActor.retryCount
        }
    }
}

// MARK: - PipelineRequestProtocol

extension RecordingRequest: PipelineRequest {

    public typealias Output = RecordingResult

    /// Starts or resumes the recording.
    public func resume() async {
        let currentState = await stateActor.state

        switch currentState {
        case .initialized:
            await stateActor.setState(.running)

            let startHandler = lock.withLock { willStartHandler }
            startHandler?()

            startTime = Date()

            do {
                try await recorder.startRecording(configuration: configuration)

                // Start waveform processing if handler is set
                if waveformHandler != nil {
                    await startWaveformProcessing()
                }

                // Start progress updates
                if progressHandler != nil {
                    await startProgressUpdates()
                }

                // Start live transcription
                if liveTranscriptionHandler != nil {
                    await startLiveTranscription()
                }
            } catch let error as UtteranceError {
                let retryResult = await executeRetryChain(error: error)

                switch retryResult {
                case .retry:
                    _ = await stateActor.incrementRetry()
                    await resume()
                case .retryWithDelay(let delay):
                    _ = await stateActor.incrementRetry()
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await resume()
                case .doNotRetry:
                    await handleError(error)
                }
            } catch {
                let error = UtteranceError.recording(
                    .engineStartFailed(reason: error.localizedDescription))
                await handleError(error)
            }

        case .suspended:
            await stateActor.setState(.running)
        // Resume recording (if supported)

        case .running, .cancelling, .finished:
            break
        }
    }

    // MARK: - Interceptor Execution

    private func executeRetryChain(error: UtteranceError) async -> RetryResult {
        // Collect all interceptors (Request + Session)
        let sessionInterceptors = await UtteranceSession.default.interceptors
        let allInterceptors = requestInterceptors + sessionInterceptors

        for interceptor in allInterceptors {
            let result = await interceptor.retry(self, dueTo: error)
            if case .retry = result { return result }
            if case .retryWithDelay = result { return result }
        }
        return .doNotRetry
    }

    /// Suspends (pauses) the recording.
    public func suspend() async {
        let currentState = await stateActor.state
        guard currentState == .running else { return }
        await stateActor.setState(.suspended)
    }

    /// Cancels the recording.
    public func cancel() async {
        await stateActor.setState(.cancelling)
        await recorder.cancelRecording()
        await stateActor.setState(.finished)
    }

    /// Executes the recording and returns the result.
    public func run() async throws -> RecordingResult {
        await resume()

        // Wait for external stop signal (this is controlled by the user)
        // For now, we need a way to signal completion
        // This will be integrated with the Session control

        return try await withCheckedThrowingContinuation { continuation in
            Task {
                // Store continuation for later completion
                self.responseCompletion = { result in
                    switch result {
                    case .success(let output):
                        continuation.resume(returning: output)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// Stops the recording and returns the result.
    ///
    /// Call this method to complete the recording session.
    @discardableResult
    public func stop() async throws -> RecordingResult {
        guard await stateActor.state == .running else {
            throw UtteranceError.recording(.invalidConfiguration(reason: "Recording not running"))
        }

        do {
            let result = try await recorder.stopRecording()
            await stateActor.setState(.finished)

            // Call handlers
            didCompleteHandler?(result)
            responseQueue.async { [responseCompletion] in
                responseCompletion?(.success(result))
            }

            return result
        } catch let error as UtteranceError {
            await handleError(error)
            throw error
        } catch {
            let utteranceError = UtteranceError.recording(
                .engineStartFailed(reason: error.localizedDescription))
            await handleError(utteranceError)
            throw utteranceError
        }
    }
}

// MARK: - Chainable Methods

// MARK: - Chainable Methods

extension RecordingRequest {

    /// Adds a waveform visualization handler with default processor.
    @discardableResult
    public func waveform(
        downsampleFactor: Int = 4,
        handler: @escaping @Sendable ([Float]) -> Void
    ) -> Self {
        let processor = DefaultWaveformProcessor(downsampleFactor: downsampleFactor)
        return waveform(provider: processor, handler: handler)
    }

    /// Adds a waveform visualization handler with custom provider.
    @discardableResult
    public func waveform(
        provider: some WaveformProvider,
        handler: @escaping @Sendable ([Float]) -> Void
    ) -> Self {
        lock.withLock {
            self.waveformProvider = provider
            self.waveformHandler = handler
        }
        return self
    }

    /// Adds a progress handler.
    @discardableResult
    public func onProgress(
        _ handler: @escaping @Sendable (RecordingProgress) -> Void
    ) -> Self {
        lock.withLock {
            self.progressHandler = handler
        }
        return self
    }

    /// Chains a transcription request.
    public func transcribe(_ configuration: TranscriptionConfiguration) -> CombinedPipelineRequest {
        CombinedPipelineRequest(
            recordingRequest: self,
            transcriptionConfiguration: configuration
        )
    }

    /// adds a live transcription handler.
    @discardableResult
    public func liveTranscription(
        configuration: TranscriptionConfiguration = .default,
        handler: @escaping @Sendable (TranscriptionResult) -> Void
    ) -> Self {
        lock.withLock {
            self.liveTranscriptionConfiguration = configuration
            self.liveTranscriptionHandler = handler
        }
        return self
    }

    /// Adds an interceptor to this request.
    @discardableResult
    public func intercept(_ interceptor: any PipelineInterceptor) -> Self {
        lock.withLock {
            self.requestInterceptors.append(interceptor)
        }
        return self
    }
}

// MARK: - ResponseHandling

extension RecordingRequest: ResponseHandling {

    @discardableResult
    public func response(
        queue: DispatchQueue,
        completion: @escaping @Sendable (Result<RecordingResult, UtteranceError>) -> Void
    ) -> Self {
        lock.withLock {
            self.responseQueue = queue
            self.responseCompletion = completion
        }

        // Auto-resume when response handler is set (like Alamofire)
        Task {
            await self.resume()
        }

        return self
    }
}

// MARK: - LifecycleHooks

extension RecordingRequest: LifecycleHooks {

    @discardableResult
    public func willStart(_ handler: @escaping VoidHandler) -> Self {
        lock.withLock {
            self.willStartHandler = handler
        }
        return self
    }

    @discardableResult
    public func didComplete(_ handler: @escaping @Sendable (RecordingResult) -> Void) -> Self {
        lock.withLock {
            self.didCompleteHandler = handler
        }
        return self
    }

    @discardableResult
    public func didFail(_ handler: @escaping ErrorHandler) -> Self {
        lock.withLock {
            self.didFailHandler = handler
        }
        return self
    }
}

// MARK: - Private Methods

extension RecordingRequest {

    private func handleError(_ error: UtteranceError) async {
        await stateActor.setState(.finished)

        let (failHandler, queue, completion) = lock.withLock {
            (didFailHandler, responseQueue, responseCompletion)
        }

        failHandler?(error)
        queue.async {
            completion?(.failure(error))
        }
    }

    private func startWaveformProcessing() async {
        let (provider, handler) = lock.withLock { (waveformProvider, waveformHandler) }
        guard let provider, let handler else { return }

        let batcher = WaveformBatcher(
            batchSize: provider.batchSize,
            downsampleFactor: 1  // Provider already handles downsampling
        )
        await batcher.setCallback(handler)

        Task {
            for await buffer in await recorder.audioBufferStream {
                // Process through provider
                let samples = provider.process(buffer: buffer)

                // Batch for UI updates
                await batcher.process(samples)

                // Adapt audio (Interceptor) - Optional: might want to move this or use original buffer
                // Note: Interceptors typically need the original buffer.
                // If we want to intercept, we should do it before waveform processing?
                // For now, keeping existing interceptor interface which takes buffer

                let sessionInterceptors = await UtteranceSession.default.interceptors
                let localInterceptors = lock.withLock { requestInterceptors }
                let allInterceptors = localInterceptors + sessionInterceptors

                for interceptor in allInterceptors {
                    _ = try? await interceptor.adapt(buffer, for: self)
                }
            }
        }
    }

    private func startProgressUpdates() async {
        let handler = lock.withLock { progressHandler }
        guard let handler, let startTime = startTime else { return }

        Task {
            var bufferCount = 0

            // Get a FRESH stream from recorder (now supports multicast)
            for await buffer in await recorder.audioBufferStream {
                bufferCount += 1

                let duration = Date().timeIntervalSince(startTime)

                // Calculate simple levels
                var peakLevel: Float = 0
                var avgLevel: Float = 0

                if let channelData = buffer.floatChannelData {
                    let frameLength = Int(buffer.frameLength)
                    if frameLength > 0 {
                        var sum: Float = 0
                        let data = channelData[0]
                        for i in 0..<frameLength {
                            let sample = abs(data[i])
                            sum += sample
                            if sample > peakLevel { peakLevel = sample }
                        }
                        avgLevel = sum / Float(frameLength)
                    }
                }

                let progress = RecordingProgress(
                    duration: duration,
                    averageLevel: avgLevel,
                    peakLevel: peakLevel,
                    bufferCount: bufferCount
                )

                await MainActor.run {
                    handler(progress)
                }
            }
        }
    }

    private func startLiveTranscription() async {
        let (configuration, handler) = lock.withLock {
            (liveTranscriptionConfiguration, liveTranscriptionHandler)
        }
        guard let configuration, let handler else { return }

        Task {
            let transcriber = Transcriber()
            let bufferStream = await recorder.sendableAudioBufferStream

            do {
                let stream = await transcriber.transcribeStream(
                    buffers: bufferStream, configuration: configuration
                )

                for try await result in stream {
                    handler(result)
                }
            } catch {
                // Log or handle error?
                // For live transcription, we might ideally report this via didFail,
                // but doing so might stop the recording if we treat it as critical.
                // For now, simpler to log or ignore, or report as non-fatal.
                // Let's rely on the handler receiving error states if we had one?
                // But handler only receives TranscriptionResult.
                // We should probably allow the handler to receive completion/failure??
                // The current API is (TranscriptionResult) -> Void.
                // We'll leave error handling silent for this MVP or log.
                print("Live transcription error: \(error)")
            }
        }
    }
}
