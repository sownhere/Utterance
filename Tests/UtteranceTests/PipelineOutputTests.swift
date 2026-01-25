import XCTest

@testable import PipelineModels
@testable import Utterance

final class PipelineOutputTests: XCTestCase {

    func testInitialization() {
        let output = PipelineOutput(
            recording: nil,
            transcription: nil,
            translation: nil
        )

        XCTAssertNil(output.recording)
        XCTAssertNil(output.transcription)
        XCTAssertNil(output.translation)
    }

    func testPartialResults() {
        let recordingResult = RecordingResult(
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), duration: 1.0, format: .m4a)
        let output = PipelineOutput(recording: recordingResult)

        XCTAssertNotNil(output.recording)
        XCTAssertNil(output.transcription)
        XCTAssertEqual(output.recording?.duration, 1.0)
    }
}
