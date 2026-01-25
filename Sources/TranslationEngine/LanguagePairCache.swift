// The MIT License (MIT)
// Copyright (c) 2024 Utterance

import Foundation
import PipelineModels

/// Stub implementation for LanguagePairCache.
///
/// This is a placeholder for future language model caching.
public actor LanguagePairCache {
    
    public init() {}
    
    /// Checks if a language pair is downloaded.
    public func isDownloaded(from: Locale.Language, to: Locale.Language) async -> Bool {
        false
    }
    
    /// Downloads a language pair.
    public func download(from: Locale.Language, to: Locale.Language) async throws {
        throw UtteranceError.translation(.serviceUnavailable)
    }
    
    /// Deletes a language pair.
    public func deleteLanguagePair(from: Locale.Language, to: Locale.Language) async throws {
        // Stub implementation
    }
}
