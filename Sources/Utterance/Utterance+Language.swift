// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import Foundation
import SpeechTranscription

// MARK: - Language Management Extensions

extension Utterance {

    /// Checks if a specific locale is supported by the Speech framework.
    ///
    /// - Parameter locale: The locale to check.
    /// - Returns: `true` if supported.
    public static func isLocaleSupported(_ locale: Locale) -> Bool {
        SpeechRecognizerManager.isSupported(locale: locale)
    }

    /// Returns a set of all locales supported by the Speech framework.
    public static var supportedLocales: Set<Locale> {
        SpeechRecognizerManager.supportedLocales
    }

    /// Checks if a locale is ready for use (including offline availability if requested).
    ///
    /// - Parameters:
    ///   - locale: The locale to check.
    ///   - requireOnDevice: If `true`, checks if on-device recognition is supported.
    /// - Returns: `true` if available.
    public static func isLocaleAvailable(_ locale: Locale, requireOnDevice: Bool = false) async
        -> Bool
    {
        // We need an instance to check this, so we use a temporary manager or the session's internal one if we had access.
        // For simplicity in this static context, we create a ephemeral manager instance.
        let manager = SpeechRecognizerManager()
        return await manager.isLocaleAvailable(locale, requireOnDevice: requireOnDevice)
    }

    /// Requests the system to download the offline model for a locale.
    ///
    /// This is a "best-effort" request as iOS manages downloads automatically.
    /// This call triggers a brief recognition task to hint the system that the language is needed.
    ///
    /// - Parameter locale: The locale to download.
    public static func requestOfflineModel(for locale: Locale) async {
        let manager = SpeechRecognizerManager()
        await manager.requestOfflineModelDownload(for: locale)
    }
}
