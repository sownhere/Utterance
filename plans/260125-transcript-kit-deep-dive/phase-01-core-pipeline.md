# Phase 01: Core Pipeline Upgrade
Status: ✅ Complete
Dependencies: None

## Objective
Upgrade the core `TranscriptionConfiguration` and `TranscriptionResult` to support deep Apple Speech features.

## Requirements
### Functional
- [x] Add `addsPunctuation` to `TranscriptionConfiguration`.
- [x] Add `shouldReportPartialResults` to `TranscriptionConfiguration`.
- [x] Add `contextualStrings` (Jargon) support.
- [x] Add `requiresOnDeviceRecognition` support.
- [x] Upgrade `TranscriptionResult` to include `segments` and `speakingRate`.
- [x] Ensure `TranscriptionRequest` respects these new configs.

## Files to Modify
- `Sources/PipelineModels/TranscriptionConfiguration.swift` - Add new properties.
- `Sources/PipelineModels/PipelineResult.swift` - Enhance TranscriptionResult.
- `Sources/SpeechTranscription/RecognitionTask.swift` - Map configs to SFSpeechRequest.

## Test Criteria
- [x] Configuration passes correctly to `SFSpeechAudioBufferRecognitionRequest`.
- [x] Results return with punctuation (when enabled).
- [x] Results return with segments (if available).

---
Next Phase: [Phase 02: Smart Segmentation](./phase-02-segmentation.md)
