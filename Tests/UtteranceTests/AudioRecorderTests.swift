import XCTest

@testable import AudioRecorder
@testable import PipelineModels

final class AudioRecorderTests: XCTestCase {

    func testRecorderInitialization() {
        let recorder = Recorder()
        // Default state should be .idle or similar conceptual state
        // Since Recorder state is actor-isolated, we check async properties if available
        // Or just verify initialization succeeded
        XCTAssertNotNil(recorder)
    }

    func testIsRecordingInitiallyFalse() async {
        let recorder = Recorder()
        let isRecording = await recorder.isRecording
        XCTAssertFalse(isRecording)
    }
}
