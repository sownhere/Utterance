# Phase 05: File Transcription
Status: ✅ Complete
Dependencies: phase-04-export-data.md

## Objective
Support transcribing pre-recorded audio files with progress reporting.

## Requirements
### Functional
- [x] `Utterance.transcribe(file: URL, config: ...)` API.
- [x] Handle `SFSpeechURLRecognitionRequest`.
- [x] Report progress (0.0 -> 1.0).

## Files to Create/Modify
- `Sources/Utterance/Request/FileTranscriptionRequest.swift` - [NEW]
- `Sources/SpeechTranscription/RecognitionTask.swift` - Support URL requests.

## Test Criteria
- [x] Can transcribe a dummy .m4a file.
- [x] Progress callback is fired.

---
Next Phase: [Phase 06: Verification](./phase-06-demo-app.md)
