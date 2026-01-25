// The MIT License (MIT)
//
// Copyright (c) 2024 Utterance
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

/// Configuration for text translation sessions.
///
/// Use this structure to configure translation parameters such as source
/// and target languages.
///
/// ```swift
/// let config = TranslationConfiguration(
///     sourceLanguage: Locale.Language(identifier: "en"),
///     targetLanguage: Locale.Language(identifier: "vi")
/// )
/// ```
public struct TranslationConfiguration: Sendable, Hashable {
    
    // MARK: - Translation Mode
    
    /// Mode of translation execution.
    public enum TranslationMode: String, Sendable, CaseIterable {
        /// Translate text in batch (wait for complete input)
        case batch
        /// Translate text as it streams in
        case streaming
    }
    
    // MARK: - Properties
    
    /// The source language for translation
    public let sourceLanguage: Locale.Language
    
    /// The target language for translation
    public let targetLanguage: Locale.Language
    
    /// The translation execution mode
    public let mode: TranslationMode
    
    // MARK: - Initialization
    
    /// Creates a new translation configuration.
    ///
    /// - Parameters:
    ///   - sourceLanguage: The source language for translation.
    ///   - targetLanguage: The target language for translation.
    ///   - mode: The translation execution mode. Default is `.batch`.
    public init(
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language,
        mode: TranslationMode = .batch
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.mode = mode
    }
    
    /// Creates a configuration from locale identifiers.
    ///
    /// - Parameters:
    ///   - source: Source language identifier (e.g., "en", "vi")
    ///   - target: Target language identifier
    ///   - mode: The translation execution mode
    public init(
        from source: String,
        to target: String,
        mode: TranslationMode = .batch
    ) {
        self.sourceLanguage = Locale.Language(identifier: source)
        self.targetLanguage = Locale.Language(identifier: target)
        self.mode = mode
    }
}

// MARK: - Convenience Factory Methods

extension TranslationConfiguration {
    
    /// Creates a translation configuration from source to target language.
    ///
    /// - Parameters:
    ///   - source: The source language
    ///   - target: The target language
    /// - Returns: A new translation configuration
    public static func from(
        _ source: Locale.Language,
        to target: Locale.Language
    ) -> TranslationConfiguration {
        TranslationConfiguration(
            sourceLanguage: source,
            targetLanguage: target
        )
    }
    
    /// Creates a translation configuration from source to target language identifiers.
    ///
    /// - Parameters:
    ///   - source: Source language identifier (e.g., "en", "vi")
    ///   - target: Target language identifier
    /// - Returns: A new translation configuration
    public static func from(
        _ source: String,
        to target: String
    ) -> TranslationConfiguration {
        TranslationConfiguration(from: source, to: target)
    }
}

// MARK: - Common Language Pairs

extension TranslationConfiguration {
    
    /// English to Vietnamese translation
    public static let englishToVietnamese = TranslationConfiguration(
        from: "en",
        to: "vi"
    )
    
    /// Vietnamese to English translation
    public static let vietnameseToEnglish = TranslationConfiguration(
        from: "vi",
        to: "en"
    )
    
    /// English to Japanese translation
    public static let englishToJapanese = TranslationConfiguration(
        from: "en",
        to: "ja"
    )
    
    /// Japanese to English translation
    public static let japaneseToEnglish = TranslationConfiguration(
        from: "ja",
        to: "en"
    )
    
    /// English to Chinese (Simplified) translation
    public static let englishToChinese = TranslationConfiguration(
        from: "en",
        to: "zh-Hans"
    )
    
    /// Chinese (Simplified) to English translation
    public static let chineseToEnglish = TranslationConfiguration(
        from: "zh-Hans",
        to: "en"
    )
    
    /// English to Korean translation
    public static let englishToKorean = TranslationConfiguration(
        from: "en",
        to: "ko"
    )
    
    /// Korean to English translation
    public static let koreanToEnglish = TranslationConfiguration(
        from: "ko",
        to: "en"
    )
}
