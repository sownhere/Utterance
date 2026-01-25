import Foundation
import PipelineModels
import Utterance

// MARK: - Protocol

/// Protocol for recording repository - abstraction over data layer
protocol RecordingRepositoryProtocol: Sendable {
    /// Start recording with live transcription
    /// - Parameters:
    ///   - onTranscription: Callback for transcription updates
    ///   - onProgress: Callback for audio level progress
    /// - Returns: Recording request handle
    func startRecording(
        configuration: TranscriptionConfiguration,
        onTranscription: @escaping @Sendable (TranscriptionResult) -> Void,
        onItem: @escaping @Sendable (TranscriptItem) -> Void,
        onProgress: @escaping @Sendable (Float) -> Void
    ) async throws -> RecordingRequest

    /// Stop the current recording
    func stopRecording(_ request: RecordingRequest) async throws

    /// Translate text
    func translate(text: String) async throws -> String
}
