import Foundation
import PipelineModels
import Utterance

// MARK: - RecordingRepository

/// Concrete implementation of RecordingRepositoryProtocol
/// Wraps Utterance library calls for data operations
final class RecordingRepository: RecordingRepositoryProtocol, @unchecked Sendable {

    func startRecording(
        configuration: TranscriptionConfiguration,
        onTranscription: @escaping @Sendable (TranscriptionResult) -> Void,
        onItem: @escaping @Sendable (TranscriptItem) -> Void,
        onProgress: @escaping @Sendable (Float) -> Void
    ) async throws -> RecordingRequest {
        let request = UT.record(.default)
            .liveTranscription(configuration: configuration) { result in
                onTranscription(result)
            }
            .onItem { item in
                onItem(item)
            }
            .onProgress { progress in
                onProgress(progress.averageLevel)
            }

        return request
    }

    func stopRecording(_ request: RecordingRequest) async throws {
        try await request.stop()
    }

    func translate(text: String) async throws -> String {
        let config = TranslationConfiguration.englishToVietnamese
        let result = try await UT.translate(text: text, configuration: config).run()
        return result.translatedText
    }
}
