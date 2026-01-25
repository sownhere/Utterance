# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.2.0] - 2026-01-25
### Added
- **File Transcription**: New `UT.transcribe(file:)` API with streaming progress support.
- **Smart Segmentation**: `StatementSeparator` splits speech into logical sentences based on silence duration (default 1.5s).
- **Export**: `TranscriptExporter` supports exporting to SRT, WebVTT, and JSON formats.
- **Metadata**: Transcription results now include `speakingRate`, `confidence` scores, and detailed timing.
- **Demo App**: Added Import/Export features, Language Picker, and rich transcript visualization.

### Changed
- **Architecture**: Refactored `RecordingRequest` to use `TranscriptionRequest` internally for consistent logic.
- **API**: `TranscriptionResult` now includes `segments` array for detailed word/phrase timing.
- **Configuration**: `TranscriptionConfiguration` now supports `addsPunctuation` flag (default true).

### Fixed
- Fixed streaming loop termination issue in `Transcriber`.
- Fixed unused variable warnings in `SpeechTranscription`.

## [0.1.0] - Initial Release
- Basic Audio Recording
- Live Transcription
- Waveform Visualization
- Translation Engine
