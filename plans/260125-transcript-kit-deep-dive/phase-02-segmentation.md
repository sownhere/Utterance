# Phase 02: Smart Segmentation
Status: ✅ Complete
Dependencies: phase-01-core-pipeline.md

## Objective
Implement "Statement Separation" to break the infinite stream into distinct `TranscriptItem`s.

## Requirements
### Functional
- [x] Create `TranscriptItem` model (id, text, range, confidence).
- [x] Implement `StatementSeparator` logic / State Machine.
    - [x] Split by Punctuation (`.`, `?`, `!`).
    - [x] Split by Silence (`timer > threshold`).
- [x] Update `Transcriber` to emit `TranscriptItem` stream (or `[TranscriptItem]`).

## Files to Create/Modify
- `Sources/Utterance/Transcript/TranscriptItem.swift` - [NEW] Data model.
- `Sources/Utterance/Transcript/StatementSeparator.swift` - [NEW] Logic.
- `Sources/Utterance/Request/TranscriptionRequest.swift` - Integrate separator.

## Test Criteria
- [x] pauses > 2s cause a new Item to be emitted.
- [x] punctuation causes a split (if configured).

---
Next Phase: [Phase 03: Language Management](./phase-03-language-mgmt.md)
