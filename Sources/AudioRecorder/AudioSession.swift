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

import AVFoundation
import Foundation
import PipelineModels

/// Manages the AVAudioSession configuration for recording.
///
/// This actor provides a safe, centralized way to configure the audio session
/// for various recording scenarios.
///
/// ```swift
/// let sessionManager = AudioSessionManager.shared
/// try await sessionManager.configure(for: .recording)
/// let hasPermission = await sessionManager.requestMicrophonePermission()
/// ```
public actor AudioSessionManager {
    
    // MARK: - Session Mode
    
    /// Audio session modes for different use cases.
    public enum Mode: Sendable {
        /// Recording from microphone
        case recording
        /// Playback only
        case playback
        /// Simultaneous recording and playback
        case playAndRecord
        
        #if os(iOS)
        var category: AVAudioSession.Category {
            switch self {
            case .recording:
                return .record
            case .playback:
                return .playback
            case .playAndRecord:
                return .playAndRecord
            }
        }
        
        var mode: AVAudioSession.Mode {
            switch self {
            case .recording, .playAndRecord:
                return .measurement
            case .playback:
                return .default
            }
        }
        
        var options: AVAudioSession.CategoryOptions {
            switch self {
            case .recording:
                return []
            case .playback:
                return []
            case .playAndRecord:
                return [.defaultToSpeaker, .allowBluetooth]
            }
        }
        #endif
    }
    
    // MARK: - Singleton
    
    /// Shared instance of the audio session manager.
    public static let shared = AudioSessionManager()
    
    // MARK: - Properties
    
    private var isConfigured = false
    private var currentMode: Mode?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configures the audio session for the specified mode.
    ///
    /// - Parameter mode: The desired audio session mode
    /// - Throws: ``UtteranceError/recording(_:)`` if configuration fails
    public func configure(for mode: Mode) async throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(mode.category, mode: mode.mode, options: mode.options)
            try session.setActive(true)
            
            currentMode = mode
            isConfigured = true
        } catch {
            throw UtteranceError.recording(.audioSessionSetupFailed(reason: error.localizedDescription))
        }
        #else
        // macOS doesn't require audio session configuration
        currentMode = mode
        isConfigured = true
        #endif
    }
    
    /// Deactivates the audio session.
    ///
    /// - Throws: ``UtteranceError/recording(_:)`` if deactivation fails
    public func deactivate() async throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            isConfigured = false
            currentMode = nil
        } catch {
            throw UtteranceError.recording(.audioSessionSetupFailed(reason: error.localizedDescription))
        }
        #else
        isConfigured = false
        currentMode = nil
        #endif
    }
    
    // MARK: - Permissions
    
    /// Requests microphone permission from the user.
    ///
    /// - Returns: `true` if permission was granted, `false` otherwise
    public func requestMicrophonePermission() async -> Bool {
        #if os(iOS)
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #else
        // macOS handles permissions differently
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
        #endif
    }
    
    /// Checks the current microphone authorization status.
    ///
    /// - Returns: The current authorization status
    public func microphoneAuthorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }
}
