# 🚀 TranscriptKit Deep Expansion Brief (v3 - Focused)

**Goal:** Build the ultimate **Smart Transcription Engine**.
**Focus:** Pure Transcription (No Translation, No Audio Eng).

---

## 1. 🧠 Core Intelligence (Deep Apple Speech Integration)

### 1.1. Smart Segmentation ("Statement Separation")
**The Problem:** Apple returns a running stream. We need distinct "sentences" or "blocks".
**The Solution:** `StatementRecognizer` with a State Machine.
- [ ] **Semantic Split:** Auto-cut on final punctuation (`.`, `?`, `!`) provided by `addsPunctuation`.
- [ ] **Silence Split:** Auto-cut when user pauses for `timer > threshold` (e.g., 2.0s).
- [ ] **Output:** Stream of `TranscriptItem` instead of one giant String.

### 1.2. Deep Configuration & Accuracy
- [ ] **Contextual Strings (Jargon):** API to inject custom words (names, medical terms, code keywords) to boost accuracy.
- [ ] **Task Hints:** Explicit modes for `dictation`, `search`, `confirmation`.
- [ ] **On-Device Enforcement:** Toggle for strict offline mode (privacy/speed).
- [ ] **Alternatives:** Show "Did you mean?" candidates for ambiguous phrases.

---

## 2. 🗣 Language Management (Transcript Specific)

*Note: Programmatic "Download" is not supported by Apple Speech (User must enable in Settings), but we can provide full management around it.*

- [ ] **Locale Discovery:** List all supported locales on the device.
- [ ] **Download Management:** 
  - Manage offline model status.
  - **Progress Reporting:** Show download progress where system APIs allow (or guide user to System Settings).
  - *Note: Direct API for downloading Speech models is limited; will maximize available system hooks.*
- [ ] **Availability Check:** proactively check `SFSpeechRecognizer.isAvailable` for a specific locale.
- [ ] **Persistence:** Save user's preferred language per-session or globally.
- [ ] **Fallback Logic:** What to do if the selected language isn't available (fallback to generic English or show alert).

---

## 3. 📄 Data & Export (The "Deep" Support)

**Goal:** Data that is useful beyond just reading.

- [ ] **Word-Level Timing:** Every word has a `startTime` and `endTime`.
- [ ] **Standard Exports:**
  - **SRT / VTT:** Auto-generate subtitle files from the transcript.
  - **JSON:** Export full metadata for analysis.
  - **Timeline:** Ready-to-render data for a UI waveform or timeline view.

---

## 4. 📂 File Transcription (Post-Processing)

- [ ] **Audio File Import:** Transcribe pre-recorded files (m4a, wav, mp3), not just microphone input.
- [ ] **Progress Reporting:** "Transcribing File... 45%" (using `SFSpeechRecognitionTask` progress).

---

## 5. 📱 Developer API (Preview)

```swift
// 1. Configure
let config = TranscriptionConfiguration(
    locale: .vietnamese,
    contextualStrings: ["Utterance", "SwiftUI", "Antigravity"],
    smartSegmentation: .on(silenceThreshold: 1.5)
)

// 2. Transcribe Live
for await detailedItem in transcriber.liveStream(config) {
    print("[\(detailedItem.startTime)] \(detailedItem.text)")
}

// 3. Export
let srtContent = transcript.export(.srt)
try srtContent.write(to: url)
```
