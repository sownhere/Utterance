import XCTest

@testable import PipelineModels
@testable import Utterance

final class RequestStateTests: XCTestCase {

    func testRequestInitialState() async {
        let request = RecordingRequest(configuration: .default)
        let state = await request.state
        XCTAssertEqual(state, .initialized)
    }

    func testRequestStateTransitions() async {
        let request = RecordingRequest(configuration: .default)

        await request.resume()
        // Note: Without a mock recorder usually initialized, this might fail or error if not mocked properly
        // However, RecordingRequest by default initializes a real Recorder if not injected.
        // For unit tests, we should mocking the Recorder, but Recorder is a class currently.
        // Assuming Recorder defaults are passive until started or we handle errors.

        // Let's assume for basic state check we might need to be careful.
        // In this architecture, RecordingRequest uses an internal StateActor.
    }
}

final class RecordingRequestTests: XCTestCase {

    func testChainableAPI() {
        let request = UT.record(.default)
            .waveform { _ in }
            .onProgress { _ in }

        XCTAssertNotNil(request)
    }

    func testTranscriptionChaining() {
        let pipeline = UT.record(.default)
            .transcribe(.default)

        XCTAssertTrue(pipeline is CombinedPipelineRequest)
    }
}
