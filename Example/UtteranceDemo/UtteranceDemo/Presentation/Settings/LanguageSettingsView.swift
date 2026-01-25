import SwiftUI
import Utterance
internal import Combine

/// View for managing speech recognition language downloads.
struct LanguageSettingsView: View {
    @StateObject private var viewModel = LanguageSettingsViewModel()

    var body: some View {
        List {
            Section {
                ForEach(viewModel.languages) { language in
                    LanguageRow(
                        language: language,
                        onDownload: {
                            Task {
                                await viewModel.downloadLanguage(language)
                            }
                        }
                    )
                }
            } header: {
                Text("Available Languages")
            } footer: {
                Text("Languages marked as 'Offline Ready' can be used without internet connection.")
            }
        }
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refreshStatus()
        }
        .task {
            await viewModel.refreshStatus()
        }
    }
}

// MARK: - Language Row

struct LanguageRow: View {
    let language: LanguageInfo
    let onDownload: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(language.displayName)
                    .font(.body)

                Text(language.locale.identifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusView
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusView: some View {
        switch language.status {
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .offlineReady:
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
                Text("Offline")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        case .notDownloaded:
            Button(action: onDownload) {
                Text("Download")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        case .downloading:
            ProgressView()
                .scaleEffect(0.8)
        case .unavailable:
            Image(systemName: "xmark.circle")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ViewModel

@MainActor
class LanguageSettingsViewModel: ObservableObject {
    @Published var languages: [LanguageInfo] = []

    private let manager = SpeechRecognizerManager()

    // Common locales to display (subset of all supported)
    private let displayLocales: [Locale] = [
        Locale(identifier: "en-US"),
        Locale(identifier: "en-GB"),
        Locale(identifier: "vi-VN"),
        Locale(identifier: "ja-JP"),
        Locale(identifier: "ko-KR"),
        Locale(identifier: "zh-CN"),
        Locale(identifier: "zh-TW"),
        Locale(identifier: "fr-FR"),
        Locale(identifier: "de-DE"),
        Locale(identifier: "es-ES"),
        Locale(identifier: "it-IT"),
        Locale(identifier: "pt-BR"),
        Locale(identifier: "ru-RU"),
        Locale(identifier: "th-TH"),
        Locale(identifier: "id-ID"),
    ]

    init() {
        // Initialize with placeholder data
        languages = displayLocales.map { locale in
            LanguageInfo(
                locale: locale,
                displayName: locale.localizedString(forIdentifier: locale.identifier)
                    ?? locale.identifier,
                status: .unavailable
            )
        }
    }

    func refreshStatus() async {
        var updatedLanguages: [LanguageInfo] = []

        for locale in displayLocales {
            let isAvailable = await manager.isLocaleAvailable(locale, requireOnDevice: false)
            let isOffline = await manager.isLocaleAvailable(locale, requireOnDevice: true)

            let status: LanguageStatus
            if isOffline {
                status = .offlineReady
            } else if isAvailable {
                status = .available
            } else if SpeechRecognizerManager.isSupported(locale: locale) {
                status = .notDownloaded
            } else {
                status = .unavailable
            }

            let displayName =
                locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
            updatedLanguages.append(
                LanguageInfo(locale: locale, displayName: displayName, status: status))
        }

        languages = updatedLanguages
    }

    func downloadLanguage(_ language: LanguageInfo) async {
        // Update status to downloading
        if let index = languages.firstIndex(where: { $0.id == language.id }) {
            languages[index].status = .downloading
        }

        // Trigger download
        await manager.requestOfflineModelDownload(for: language.locale)

        // Wait a bit then refresh (download is async system-level)
        try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2s
        await refreshStatus()
    }
}

// MARK: - Models

struct LanguageInfo: Identifiable {
    let id = UUID()
    let locale: Locale
    let displayName: String
    var status: LanguageStatus
}

enum LanguageStatus {
    case available  // Can use (online)
    case offlineReady  // Downloaded for offline use
    case notDownloaded  // Supported but needs download
    case downloading  // Currently downloading
    case unavailable  // Not supported on this device
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
