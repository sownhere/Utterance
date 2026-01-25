import XCTest

@testable import PipelineModels
@testable import Utterance

final class ErrorTests: XCTestCase {

    func testErrorCodeMapping() {
        let recordingError = UtteranceError.recording(.engineStartFailed(reason: "test"))
        XCTAssertEqual(recordingError.code, .engineStartFailed)

        let permissionError = UtteranceError.permission(.microphoneNotAuthorized)
        XCTAssertEqual(permissionError.code, .permissionDenied)
    }

    func testLocalizedDescription() {
        let error = UtteranceError.transcription(.noSpeechDetected)
        XCTAssertEqual(
            error.localizedDescription, "Transcription Error: No speech detected in audio")
    }
}
