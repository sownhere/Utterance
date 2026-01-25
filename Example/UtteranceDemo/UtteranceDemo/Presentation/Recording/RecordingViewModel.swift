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
    var items: [DemoTranscriptItem] = []
    var liveText: String = ""

    var lastRecordingURL: URL?
    var showError = false
    var errorMessage = ""
    var audioLevel: Float = 0
    var selectedLocale: Locale = Locale(identifier: "en-US")
    let availableLocales: [Locale] = [
        Locale(identifier: "en-US"),
        Locale(identifier: "vi-VN"),
        Locale(identifier: "ja-JP"),
        Locale(identifier: "ko-KR"),
    ]

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
            let config = TranscriptionConfiguration(
                locale: selectedLocale,
                taskHint: .dictation
            )

            let request = try await repository.startRecording(
                configuration: config,
                onTranscription: { [weak self] result in
                    Task { @MainActor [weak self] in
                        self?.handleTranscriptionUpdate(result)
                    }
                },
                onItem: { [weak self] item in
                    Task { @MainActor [weak self] in
                        self?.handleItemAndTranslate(item)
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
    }

    private func handleItemAndTranslate(_ utteranceItem: TranscriptItem) {
        // Map to local item
        // We use Utterance item ID if possible, or create new.
        // Demo Item expects UUID. Utterance Item has UUID.

        let newItem = DemoTranscriptItem(
            id: utteranceItem.id,
            text: utteranceItem.text,
            isFinal: true,
            timestamp: utteranceItem.timeRange.lowerBound,
            duration: utteranceItem.timeRange.upperBound - utteranceItem.timeRange.lowerBound
        )

        self.items.append(newItem)

        // Auto-translate if needed (or simply placeholder)
        Task {
            await translate(newItem)
        }
    }

    func translate(_ item: DemoTranscriptItem) async {
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

    // MARK: - File Transcription

    func transcribeFile(_ url: URL) async {
        guard url.startAccessingSecurityScopedResource() else {
            // If it's a file from picker, we need security scope, though simple import usually copies it.
            // If copied, we iterate.
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            isRecording = true
            liveText = "Processing file..."
            items = []
            translations = [:]

            // Use the file transcription API
            // We can't use Repository.startRecording since that uses Recorder.
            // We need a repository method for file, OR direct Utterance usage if Repository allows.
            // For Demo, direct usage is fine to show API, but Repository abstraction is cleaner.
            // Let's use UT directly here to demonstrate the Phase 05 API.

            // Phase 05 API: UT.transcribe(file: url, configuration: .default)
            // But we want streaming to populate items.
            // TranscriptionRequest has .onItem chaining.

            let config = TranscriptionConfiguration(
                locale: selectedLocale,
                taskHint: .dictation
            )

            let request = try await UT.transcribe(file: url, configuration: config)
                .onPartialResult { [weak self] partial in
                    Task { @MainActor [weak self] in
                        self?.liveText = partial
                    }
                }
                .onItem { [weak self] item in
                    Task { @MainActor [weak self] in
                        // Reuse same handler mapping logic
                        self?.handleItemAndTranslate(item)
                    }
                }
                .onProgress { [weak self] progress in
                    Task { @MainActor [weak self] in
                        // We can't update audioLevel easily from progress (it provides simple level? no)
                        // Progress gives us percentage maybe?
                        // TranscriptionProgress has segments but not 0-1 float for UI bar.
                        // We'll just show spinner or indeterminate state?
                        // Or use progress.speakingRate?
                        // Let's just simulate activity.
                        self?.audioLevel = Float.random(in: 0.1...0.5)
                    }
                }
                .run()

            // Finalize
            isRecording = false
            liveText = ""
            lastRecordingURL = url

        } catch {
            showError(error)
            isRecording = false
            liveText = ""
        }
    }

    // MARK: - Export

    func exportTranscript(format: ExportFormat) -> URL? {
        // Convert Demo items back to TranscriptItems for export
        // Or construct Export items.
        // ExportFormat expects [TranscriptItem].
        // We have [DemoTranscriptItem].
        // We map them.

        // Note: DemoTranscriptItem and TranscriptItem share structure.
        let sourceItems = items.map { demoItem in
            TranscriptItem(
                id: demoItem.id,
                text: demoItem.text,
                start: demoItem.timestamp,
                end: demoItem.timestamp + demoItem.duration,
                confidence: 1.0,  // Demo doesn't store confidence
                alternatives: []
            )
        }

        do {
            let content = try TranscriptExporter.export(sourceItems, to: format)

            // Write to temp file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName =
                "transcript_\(Date().formatted(date: .numeric, time: .omitted)).\(format.fileExtension)"
            let fileURL = tempDir.appendingPathComponent(fileName)

            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            showError(error)
            return nil
        }
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
