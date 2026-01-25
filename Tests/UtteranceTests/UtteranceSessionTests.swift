import XCTest

@testable import PipelineModels
@testable import Utterance

final class UtteranceSessionTests: XCTestCase {

    func testSingletonAccess() {
        let session = UtteranceSession.default
        XCTAssertNotNil(session)
    }

    func testInterceptorManagement() async {
        let session = UtteranceSession()

        // Initially empty
        var interceptors = await session.interceptors
        XCTAssertTrue(interceptors.isEmpty)

        // Add interceptor
        let mockInterceptor = RetryInterceptor(maxRetries: 1)
        await session.addInterceptor(mockInterceptor)

        interceptors = await session.interceptors
        XCTAssertEqual(interceptors.count, 1)
        XCTAssertTrue(interceptors.first is RetryInterceptor)
    }

    func testChainableRequestCreation() {
        let session = UtteranceSession()

        let request = session.record(.default)
        XCTAssertNotNil(request)
        XCTAssertEqual(request.configuration.sampleRate, 16000)
    }
}
