import SwiftUI

/// Main view demonstrating Utterance recording and transcription.
struct RecordingView: View {
    @Bindable var viewModel: RecordingViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            transcriptList
            bottomControlArea
                .allowsHitTesting(false)
        }
        .navigationTitle("Utterance")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Subviews

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isRecording ? Color.red : Color.secondary)
                .frame(width: 8, height: 8)
                .padding(4)
                .background(Material.regular, in: Circle())

            Text(viewModel.statusText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Material.thin, in: Capsule())
    }

    private enum ScrollTarget: Hashable {
        case item(UUID)
        case live
    }

    @State private var scrollPosition: ScrollTarget?

    private var transcriptList: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                // Padding top
                Color.clear.frame(height: 10)

                // Completed items
                Section {
                    ForEach(viewModel.items) { item in
                        TranscriptBubble(item: item, isLive: false) {
                            Task {
                                await viewModel.translate(item)
                            }
                        }
                        .id(ScrollTarget.item(item.id))
                    }
                } header: {
                    statusHeader
                        .padding(.top, 8)
                }

                // Live Item
                if viewModel.isRecording && !viewModel.liveText.isEmpty {
                    let liveItem = TranscriptItem(text: viewModel.liveText, isFinal: false)
                    TranscriptBubble(item: liveItem, isLive: true) {}
                        .id(ScrollTarget.live)
                }

                // Bottom spacer for safe area
                Color.clear.frame(height: 160)
            }
            .scrollTargetLayout()
            .padding(.horizontal, 16)
        }
        .scrollPosition(id: $scrollPosition, anchor: .bottom)
        .onChange(of: viewModel.liveText) { _, _ in
            withAnimation {
                scrollPosition = .live
            }
        }
        .onChange(of: viewModel.items) { _, _ in
            withAnimation {
                if let last = viewModel.items.last {
                    scrollPosition = .item(last.id)
                }
            }
        }
    }

    private var bottomControlArea: some View {
        ZStack(alignment: .center) {
            // Waveform Background
            if viewModel.isRecording {
                SiriWaveformView(audioLevel: viewModel.audioLevel)
                    .frame(height: 180)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.2),
                                .init(color: .black, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            } else {
                // Placeholder gradient or empty space
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
            }

            // Record Button
            recordButton
                .padding(.bottom, 20)
        }
        .frame(height: 180)
        .background(
            // Blur backdrop for the bottom area
            Rectangle()
                .fill(Material.ultraThin)
                .mask(
                    LinearGradient(
                        colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .center)
                )
                .ignoresSafeArea()
        )
    }

    private var recordButton: some View {
        Button {
            Task {
                await viewModel.toggleRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.accentColor)
                    .frame(width: 72, height: 72)
                    .shadow(
                        color: (viewModel.isRecording ? Color.red : Color.accentColor).opacity(0.4),
                        radius: 10, x: 0, y: 5)

                if viewModel.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isRecording)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RecordingView(viewModel: RecordingViewModel(repository: RecordingRepository()))
}
