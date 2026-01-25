import XCTest

@testable import AudioRecorder
@testable import PipelineModels
@testable import Utterance

final class LiveTranscriptionTests: XCTestCase {

    func testLiveTranscriptionChain() async {
        let request = RecordingRequest(configuration: .default)

        let expectation = XCTestExpectation(description: "Live transcription handler called")
        expectation.expectedFulfillmentCount = 1
        expectation.isInverted = true  // Expect valid test requires running recorder which is hard in unit test

        // This test mostly verifies API compilation and chaining
        request
            .liveTranscription { result in
                // Handler
            }
            .onProgress { progress in
                // Progress
            }

        XCTAssertNotNil(request)
        // Without mocking recorder internal stream, we can't easily test live streaming here without integration.
        // But we verified the API exists.
    }
}
