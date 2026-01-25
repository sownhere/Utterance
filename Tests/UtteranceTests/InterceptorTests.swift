import AVFoundation
import XCTest

@testable import PipelineModels
@testable import Utterance

final class InterceptorTests: XCTestCase {

    func testRetryInterceptorRetriesOnError() async {
        let interceptor = RetryInterceptor(
            maxRetries: 3,
            retryableErrors: [.transcriptionFailed]
        )
        let mockRequest = MockPipelineRequest()

        let result = await interceptor.retry(
            mockRequest,
            dueTo: .transcription(.recognitionFailed(reason: "test"))
        )

        // Default delay is 0.5
        if case .retryWithDelay(let delay) = result {
            XCTAssertEqual(delay, 0.5)
        } else {
            XCTFail("Expected retryWithDelay, got \(result)")
        }
    }

    func testRetryInterceptorStopsAfterMaxRetries() async {
        let interceptor = RetryInterceptor(maxRetries: 3)
        let mockRequest = MockPipelineRequest()
        await mockRequest.setRetryCount(3)

        let result = await interceptor.retry(
            mockRequest,
            dueTo: .transcription(.recognitionFailed(reason: "test"))
        )

        if case .doNotRetry = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected doNotRetry, got \(result)")
        }
    }
}
