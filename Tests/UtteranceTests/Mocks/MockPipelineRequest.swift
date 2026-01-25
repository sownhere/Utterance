import Foundation

@testable import PipelineModels
@testable import Utterance

final actor MockPipelineRequest: PipelineRequest {
    typealias Output = Void

    nonisolated let id = RequestID()
    var state: RequestState = .initialized
    var retryCount: Int = 0

    func resume() async {
        state = .running
    }

    func suspend() async {
        state = .suspended
    }

    func cancel() async {
        state = .cancelling
    }

    func run() async throws {
        await resume()
    }

    func setRetryCount(_ count: Int) {
        self.retryCount = count
    }
}
