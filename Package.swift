// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Utterance",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // 1. The Full Suite (Main)
        .library(
            name: "Utterance",
            targets: ["Utterance"]
        ),

        // 2. Core (Shared Models & Protocols)
        .library(
            name: "UtteranceCore",
            targets: ["PipelineModels"]
        ),

        // 3. Audio Only (Recording Engine)
        .library(
            name: "UtteranceAudio",
            targets: ["AudioRecorder"]
        ),

        // 4. Transcription (Speech-to-Text)
        .library(
            name: "UtteranceTranscript",
            targets: ["SpeechTranscription"]
        ),

        // 5. Translation
        .library(
            name: "UtteranceTranslation",
            targets: ["TranslationEngine"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        // Core domain models
        .target(name: "PipelineModels"),

        // Low-level audio capture
        .target(
            name: "AudioRecorder",
            dependencies: ["PipelineModels"]
        ),

        // Speech recognition
        .target(
            name: "SpeechTranscription",
            dependencies: ["PipelineModels", "AudioRecorder"]
        ),

        // Translation
        .target(
            name: "TranslationEngine",
            dependencies: ["PipelineModels", "SpeechTranscription"]
        ),

        // Public SDK facade (what users import)
        .target(
            name: "Utterance",
            dependencies: [
                "PipelineModels",
                "AudioRecorder",
                "SpeechTranscription",
                "TranslationEngine",
            ]
        ),

        .testTarget(
            name: "UtteranceTests",
            dependencies: ["Utterance"]
        ),
    ]
)
