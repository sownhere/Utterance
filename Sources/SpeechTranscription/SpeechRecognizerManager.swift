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
import PipelineModels
@preconcurrency import Speech

/// Manages SFSpeechRecognizer instances for different locales.
///
/// This actor caches recognizer instances and handles authorization requests.
///
/// ```swift
/// let manager = SpeechRecognizerManager()
/// let status = await manager.requestAuthorization()
///
/// if status == .authorized {
///     let recognizer = try await manager.getRecognizer(for: Locale(identifier: "en-US"))
///     // Use recognizer
/// }
/// ```
public actor SpeechRecognizerManager {
    
    // MARK: - Properties
    
    /// Cached recognizers by locale identifier
    private var recognizers: [String: SFSpeechRecognizer] = [:]
    
    // MARK: - Initialization
    
    /// Creates a new speech recognizer manager.
    public init() {}
    
    // MARK: - Recognizer Access
    
    /// Gets or creates a speech recognizer for the specified locale.
    ///
    /// - Parameter locale: The locale for speech recognition
    /// - Returns: The speech recognizer for the locale
    /// - Throws: ``UtteranceError/transcription(_:)`` if not available
    public func getRecognizer(for locale: Locale) throws -> SFSpeechRecognizer {
        let identifier = locale.identifier
        
        // Return cached recognizer if available
        if let cached = recognizers[identifier] {
            guard cached.isAvailable else {
                throw UtteranceError.transcription(.recognizerUnavailable(locale: identifier))
            }
            return cached
        }
        
        // Create new recognizer
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw UtteranceError.transcription(.recognizerUnavailable(locale: identifier))
        }
        
        // Check availability
        guard recognizer.isAvailable else {
            throw UtteranceError.transcription(.recognizerUnavailable(locale: identifier))
        }
        
        recognizers[identifier] = recognizer
        return recognizer
    }
    
    /// Removes a cached recognizer for the specified locale.
    ///
    /// - Parameter locale: The locale to remove
    public func removeRecognizer(for locale: Locale) {
        recognizers.removeValue(forKey: locale.identifier)
    }
    
    /// Clears all cached recognizers.
    public func clearCache() {
        recognizers.removeAll()
    }
    
    // MARK: - Authorization
    
    /// Requests speech recognition authorization from the user.
    ///
    /// - Returns: The authorization status after the request
    public func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    /// Gets the current authorization status.
    ///
    /// - Returns: The current authorization status
    public nonisolated func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }
    
    // MARK: - Locale Support
    
    /// Checks if a locale is supported for speech recognition.
    ///
    /// - Parameter locale: The locale to check
    /// - Returns: `true` if the locale is supported
    public nonisolated static func isSupported(locale: Locale) -> Bool {
        SFSpeechRecognizer.supportedLocales().contains(locale)
    }
    
    /// Gets the set of supported locales for speech recognition.
    ///
    /// - Returns: Set of supported locales
    public nonisolated static var supportedLocales: Set<Locale> {
        SFSpeechRecognizer.supportedLocales()
    }
}
