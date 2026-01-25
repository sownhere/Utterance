# Phase 04: Data & Export
Status: ✅ Complete
Dependencies: phase-03-language-mgmt.md

## Objective
Enable exporting transcripts to standard formats (SRT, VTT, JSON).

## Requirements
### Functional
- [x] `TranscriptExporter` class.
- [x] `export(to: .srt)` - Generate SubRip format.
- [x] `export(to: .vtt)` - Generate WebVTT format.
- [x] `export(to: .json)` - Full metadata dump.

## Files to Create/Modify
- `Sources/Utterance/Export/TranscriptExporter.swift` - [NEW] Logic.
- `Sources/Utterance/Export/ExportFormat.swift` - [NEW] Enums.

## Test Criteria
- [x] Generated SRT file is valid (timecodes match).
- [x] JSON export contains all fields.

---
Next Phase: [Phase 05: File Transcription](./phase-05-file-transcription.md)
