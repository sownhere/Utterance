// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import AVFoundation
import Foundation
import PipelineModels

/// Stub implementation for TranslationSessionManager.
///
/// This is a placeholder for future translation functionality.
public actor TranslationSessionManager {
    
    /// Shared instance.
    public static let shared = TranslationSessionManager()
    
    private init() {}
    
    /// Checks if translation is available between two languages.
    public static func isSupported(from: Locale.Language, to: Locale.Language) async -> Bool {
        // Stub implementation
        false
    }
    
    /// Gets supported languages for translation.
    public static func supportedLanguages() async -> [Locale.Language] {
        // Stub implementation
        []
    }
}
