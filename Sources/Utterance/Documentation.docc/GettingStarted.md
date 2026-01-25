# Getting Started with Utterance

Learn how to integrate Utterance into your app to enable recording and transcription.

## Overview

Utterance provides a streamlined API for handling audio workflows. This guide walks you through the initial setup, permission handling, and starting your first recording session.

## Installation

Add Utterance to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sownhere/Utterance.git", from: "1.0.0")
]
```

## Basic Usage

### 1. Import the Framework

```swift
import Utterance
```

### 2. Check Permissions

Before recording, ensure you have microphone access.

```swift
let granted = await AVAudioApplication.requestRecordPermission()
guard granted else { return }
```

### 3. Start Recording

Use the ``UT`` facade to start a default recording session.

```swift
do {
    let result = try await UT.record(.default).run()
    print("Recording saved to: \(result.fileURL)")
} catch {
    print("Recording failed: \(error)")
}
```

## Real-time Transcription

To use real-time transcription, you can access the session directly.

```swift
let session = UtteranceSession.shared
// Configuration logic here...
```
