import SwiftUI

/// Where in the game picture the subtitles are. Drag the box, or its corner to resize it.
struct RegionPicker: View {
    @Binding var region: CGRect
    @State private var start: CGRect?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let frame = CGRect(
                x: region.minX * size.width, y: region.minY * size.height,
                width: region.width * size.width, height: region.height * size.height
            )
            ZStack(alignment: .topLeading) {
                screen
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.appAccent.opacity(0.18))
                    .strokeBorder(Color.appAccent, style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
                    .overlay {
                        Text(verbatim: "Subtitles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                    .gesture(drag(in: size) { origin, move in origin.offsetBy(dx: move.width, dy: move.height) })
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .shadow(radius: 2)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
                    .offset(x: frame.maxX - 22, y: frame.maxY - 22)
                    .gesture(drag(in: size) { origin, move in
                        CGRect(x: origin.minX, y: origin.minY, width: origin.width + move.width, height: origin.height + move.height)
                    })
                    .accessibilityHidden(true)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        // Drag offsets mean the same thing in both directions.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(.remoteRegionTitle))
    }

    /// A plain picture of a game: dark scene, a line of subtitle near the bottom.
    private var screen: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.12)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) {
                Capsule().fill(.white.opacity(0.55)).frame(width: 160, height: 6).padding(.bottom, 26)
            }
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.appOutline, lineWidth: 1) }
    }

    /// Moves in points, converted to the picture's 0...1 space.
    private func drag(in size: CGSize, _ change: @escaping (CGRect, CGSize) -> CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let origin = start ?? region
                start = origin
                let move = CGSize(width: value.translation.width / size.width, height: value.translation.height / size.height)
                region = RemotePlaySettings.clamped(change(origin, move))
            }
            .onEnded { _ in start = nil }
    }
}
