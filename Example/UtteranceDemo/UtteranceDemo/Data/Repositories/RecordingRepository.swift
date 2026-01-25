import Foundation
import PipelineModels
import Utterance

// MARK: - RecordingRepository

/// Concrete implementation of RecordingRepositoryProtocol
/// Wraps Utterance library calls for data operations
final class RecordingRepository: RecordingRepositoryProtocol, @unchecked Sendable {

    func startRecording(
        onTranscription: @escaping @Sendable (TranscriptionResult) -> Void,
        onProgress: @escaping @Sendable (Float) -> Void
    ) async throws -> RecordingRequest {
        let request = UT.record(.default)
            .liveTranscription(configuration: .default) { result in
                onTranscription(result)
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
