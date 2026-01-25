# Phase 03: Language Management
Status: ✅ Complete
Dependencies: phase-02-segmentation.md

## Objective
Provide robust APIs to discover, check, and manage speech locales.

## Requirements
### Functional
- [x] `TranscriptionManager.supportedLocales()` - Return all SFSpeechRecognizer locales.
- [x] `TranscriptionManager.isLocaleAvailable(Locale)` - Check availability.
- [x] `TranscriptionManager.requestDownload(Locale)` - (Best effort) guide user to Settings or trigger request.
- [x] Monitor availability changes (delegate/notification).

## Files to Create/Modify
- `Sources/SpeechTranscription/SpeechRecognizerManager.swift` - Add discovery APIs.
- `Sources/Utterance/Utterance+Language.swift` - Public facade.

## Test Criteria
- [x] Can list all supported languages on device.
- [x] Can determine if a specific language is available offline (via `isAvailable`).

---
Next Phase: [Phase 04: Data & Export](./phase-04-export-data.md)
