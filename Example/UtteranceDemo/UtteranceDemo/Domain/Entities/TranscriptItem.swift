import Foundation

/// Represents a single item in the transcript (e.g., a sentence or phrase).
struct DemoTranscriptItem: Identifiable, Equatable {
    let id: UUID
    var text: String
    var translation: String?
    let timestamp: TimeInterval
    let duration: TimeInterval
    let isFinal: Bool

    // For manual creation
    init(
        id: UUID = UUID(),
        text: String, isFinal: Bool, timestamp: TimeInterval = Date().timeIntervalSince1970,
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.isFinal = isFinal
        self.translation = nil
    }

    // Check if content matches to decide about updating vs replacing
    static func == (lhs: DemoTranscriptItem, rhs: DemoTranscriptItem) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text && lhs.translation == rhs.translation
            && lhs.isFinal == rhs.isFinal
    }
}
