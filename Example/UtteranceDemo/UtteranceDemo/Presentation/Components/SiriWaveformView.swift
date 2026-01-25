import SwiftUI

struct SiriWaveformView: View {
    var audioLevel: Float

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let width = size.width
                let height = size.height
                let midHeight = height / 2

                // Colors for the waveform layers
                let colors: [Color] = [.cyan, .purple, .blue]

                // Base amplitude scaled by audio level (with a minimum "breathing" amount)
                // audioLevel is typically 0.0 to 1.0
                let baseDescription = 0.5 + Double(audioLevel) * 1.5

                for (index, color) in colors.enumerated() {
                    let i = Double(index)
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: midHeight))

                    // Parameters for each wave layer to make them distinct
                    let frequency = 2.0 + i * 0.5
                    let phaseShift = time * (3.0 + i)
                    let amplitude = (height * 0.3) * baseDescription * (1.0 - i * 0.2)

                    for x in stride(from: 0, to: width, by: 2) {
                        let relativeX = x / width

                        // Sine wave formula: y = A * sin(2πft + phase)
                        // Modulating amplitude by a bell curve (sin(πx)) to taper ends
                        let envelope = sin(relativeX * .pi)

                        let y =
                            midHeight + sin(relativeX * .pi * frequency + phaseShift) * amplitude
                            * envelope
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    path.addLine(to: CGPoint(x: width, y: midHeight))

                    // Stroke style with blur for glow effect
                    context.blendMode = .plusLighter
                    context.addFilter(.blur(radius: 4))
                    context.stroke(path, with: .color(color), lineWidth: 4)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SiriWaveformView(audioLevel: 0.5)
            .frame(height: 150)
    }
}
