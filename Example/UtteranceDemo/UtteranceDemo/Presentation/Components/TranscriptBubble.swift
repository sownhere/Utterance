import SwiftUI
import Utterance

struct TranscriptBubble: View {
    let item: DemoTranscriptItem
    let isLive: Bool
    let onTranslate: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Timestamp (Leading)
            Text(formattedTimestamp)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
                .frame(width: 40, alignment: .trailing)

            // Bubble
            VStack(alignment: .leading, spacing: 4) {
                // Original Text
                Text(item.text)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Ensure live text is visible even if empty (though usually filtered)
                    .opacity(item.text.isEmpty ? 0.5 : 1)

                // Translation
                if let translation = item.translation {
                    Divider()
                        .overlay(Color.primary.opacity(0.1))

                    Text(translation)
                        .font(.system(.body, design: .rounded))
                        .italic()
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Translate Action for non-translated finalized items
                if !isLive && item.translation == nil && !item.text.isEmpty {
                    Button(action: onTranslate) {
                        Label("Translate", systemImage: "translate")
                            .font(.caption2)
                            .padding(.top, 4)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isLive ? Material.thick : Material.regular)
                // Custom corners if desired, or uniform
            )
            .clipShape(
                // Chat bubble shape with flat bottom-left
                .rect(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 4,
                    bottomTrailingRadius: 18,
                    topTrailingRadius: 18
                )
            )
            .overlay(
                // Live pulsing border
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isLive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                    .padding(1)
                    .clipShape(
                        .rect(
                            topLeadingRadius: 18,
                            bottomLeadingRadius: 4,
                            bottomTrailingRadius: 18,
                            topTrailingRadius: 18
                        )
                    )
            )

            Spacer()
        }
        .transition(.scale(scale: 0.95, anchor: .bottomLeading).combined(with: .opacity))
    }

    private var formattedTimestamp: String {
        let date = Date(timeIntervalSince1970: item.timestamp)
        return date.formatted(date: .omitted, time: .standard)
    }
}
