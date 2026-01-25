import Foundation
import PipelineModels
import SwiftUI
import Utterance

// MARK: - RecordingViewModel

@Observable
@MainActor
final class RecordingViewModel {

    // MARK: - Dependencies

    private let repository: RecordingRepositoryProtocol

    // MARK: - State

    var isRecording = false
    var items: [TranscriptItem] = []
    var liveText: String = ""

    var lastRecordingURL: URL?
    var showError = false
    var errorMessage = ""
    var audioLevel: Float = 0

    // MARK: - Private State

    private var translations: [TimeInterval: String] = [:]
    private var currentRequest: RecordingRequest?

    // MARK: - Computed

    var statusText: String {
        isRecording ? "Recording..." : "Ready"
    }

    // MARK: - Init

    init(repository: RecordingRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Actions

    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    private func startRecording() async {
        do {
            // Reset state
            items = []
            translations = [:]
            liveText = ""
            isRecording = true

            // Start recording via repository
            let request = try await repository.startRecording(
                onTranscription: { [weak self] result in
                    Task { @MainActor [weak self] in
                        self?.handleTranscriptionUpdate(result)
                    }
                },
                onProgress: { [weak self] level in
                    Task { @MainActor [weak self] in
                        self?.audioLevel = level
                    }
                }
            )

            currentRequest = request
            let result = try await request.run()

            // Completed
            lastRecordingURL = result.fileURL
            isRecording = false
            currentRequest = nil

        } catch {
            if (error as? UtteranceError) != .recording(.cancelled) {
                showError(error)
            }
            isRecording = false
            currentRequest = nil
        }
    }

    private func stopRecording() async {
        guard let request = currentRequest else { return }
        do {
            try await repository.stopRecording(request)
        } catch {
            showError(error)
        }
    }

    private func handleTranscriptionUpdate(_ result: TranscriptionResult) {
        liveText = result.text

        var newItems: [TranscriptItem] = []

        var currentSentence = ""
        var sentenceStartTime: TimeInterval?
        var sentenceDuration: TimeInterval = 0

        // Helper to finalize a sentence
        func finalizeSentence(isFinal: Bool) {
            guard !currentSentence.isEmpty, let startTime = sentenceStartTime else { return }

            let trimmed = currentSentence.trimmingCharacters(in: .whitespaces)

            // Try to find existing item to preserve identity (for animation)
            var idToUse = UUID()
            if let existing = self.items.first(where: { abs($0.timestamp - startTime) < 0.001 }) {
                idToUse = existing.id
            }

            var item = TranscriptItem(
                id: idToUse,
                text: trimmed,
                isFinal: isFinal,  // Only the very last sentence is truly final if result.isFinal is true
                timestamp: startTime,
                duration: sentenceDuration
            )
            item.translation = translations[startTime]
            newItems.append(item)

            // Reset
            currentSentence = ""
            sentenceStartTime = nil
            sentenceDuration = 0
        }

        for segment in result.segments {
            if sentenceStartTime == nil {
                sentenceStartTime = segment.timestamp
            }

            currentSentence += segment.text + " "
            sentenceDuration += segment.duration

            // Check for end of sentence punctuation
            let trimmed = segment.text.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!") {
                finalizeSentence(isFinal: true)  // Treat punctuated sentences as "stable"
            }
        }

        // Add any remaining incomplete text as a "live" item or final item if result is final
        if !currentSentence.isEmpty {
            finalizeSentence(isFinal: result.isFinal)
        }

        // Fallback if no segments provided but text exists (shouldn't happen often)
        if newItems.isEmpty && !result.text.isEmpty {
            let item = TranscriptItem(
                text: result.text,
                isFinal: result.isFinal,
                timestamp: Date().timeIntervalSince1970,  // Fallback timestamp
                duration: 0
            )
            newItems.append(item)
        }

        self.items = newItems
    }

    func translate(_ item: TranscriptItem) async {
        guard item.translation == nil else { return }

        do {
            let translatedText = try await repository.translate(text: item.text)

            // Cache translation by timestamp (which acts as ID)
            translations[item.timestamp] = translatedText

            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].translation = translatedText
            }
        } catch {
            showError(error)
        }
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
