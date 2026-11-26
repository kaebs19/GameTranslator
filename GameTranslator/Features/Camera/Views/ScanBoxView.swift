import SwiftUI

/// Reading box over the picture. Outside is dimmed; handles appear while editing.
struct ScanBoxView: View {
    @Binding var box: ScanBox
    let isEditing: Bool
    let status: ReadingStatus
    /// The box when the current drag began.
    @State private var start: ScanBox?

    private static let touchSize: CGFloat = 44
    private static let corner = AppRadius.small
    private static let dashes = StrokeStyle(lineWidth: 3, lineCap: .round, dash: [16, 12])

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let frame = box.frame(in: size)
            ZStack(alignment: .topLeading) {
                dimming(around: frame)
                outline(frame)
                    .gesture(drag { $0.moved(by: $1, in: size) }, isEnabled: isEditing)
                if !isEditing, let title = status.title { statusLabel(title, frame, size) }
                if isEditing {
                    ForEach(ScanBox.Handle.allCases, id: \.self) { handle in
                        knob(handle)
                            .position(point(handle, frame))
                            .gesture(drag { $0.resized(handle, by: $1, in: size) })
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private func dimming(around frame: CGRect) -> some View {
        Canvas { context, size in
            var path = Path(CGRect(origin: .zero, size: size))
            path.addRoundedRect(in: frame, cornerSize: CGSize(width: Self.corner, height: Self.corner))
            context.fill(path, with: .color(AppPalette.background.color.opacity(0.55)), style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(false)
    }

    private func outline(_ frame: CGRect) -> some View {
        RoundedRectangle(cornerRadius: Self.corner)
            .strokeBorder(isEditing ? AnyShapeStyle(AppGradient.brand) : status.outline, style: Self.dashes)
            .animation(.easeInOut(duration: 0.2), value: status)
            .overlay {
                if isEditing {
                    AppLabel(.homeBoxHint, icon: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, AppSpacing.regular)
                }
            }
            .contentShape(.rect)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .accessibilityLabel(Text(.cameraBox))
    }

    /// Below the box, or inside it when it reaches the bottom.
    private func statusLabel(_ title: LocalizedStringResource, _ frame: CGRect, _ size: CGSize) -> some View {
        let below = frame.maxY + OverlayPlacement.statusHeight / 2 + 4
        let fits = below + OverlayPlacement.statusHeight / 2 <= size.height
        return Text(title)
            .font(.caption.weight(.semibold))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .foregroundStyle(status.color)
            .padding(.horizontal, AppSpacing.medium)
            .frame(height: OverlayPlacement.statusHeight - 4)
            .background(Color.appSurface.opacity(0.94), in: .capsule)
            .fixedSize()
            .position(x: frame.midX, y: fits ? below : frame.maxY - OverlayPlacement.statusHeight / 2 - 4)
            .allowsHitTesting(false)
    }

    private func knob(_ handle: ScanBox.Handle) -> some View {
        let isSide = handle == .left || handle == .right
        return RoundedRectangle(cornerRadius: handle.isCorner ? 5 : 3)
            .fill(.white)
            .frame(width: handle.isCorner ? 18 : (isSide ? 6 : 34), height: handle.isCorner ? 18 : (isSide ? 34 : 6))
            .shadow(color: .black.opacity(0.4), radius: 2)
            .frame(width: Self.touchSize, height: Self.touchSize)
            .contentShape(.rect)
    }

    private func point(_ handle: ScanBox.Handle, _ frame: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: CGPoint(x: frame.minX, y: frame.minY)
        case .topRight: CGPoint(x: frame.maxX, y: frame.minY)
        case .bottomLeft: CGPoint(x: frame.minX, y: frame.maxY)
        case .bottomRight: CGPoint(x: frame.maxX, y: frame.maxY)
        case .top: CGPoint(x: frame.midX, y: frame.minY)
        case .bottom: CGPoint(x: frame.midX, y: frame.maxY)
        case .left: CGPoint(x: frame.minX, y: frame.midY)
        case .right: CGPoint(x: frame.maxX, y: frame.midY)
        }
    }

    private func drag(_ change: @escaping (ScanBox, CGSize) -> ScanBox) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let origin = start ?? box
                start = origin
                box = change(origin, value.translation)
            }
            .onEnded { _ in start = nil }
    }
}

private extension ReadingStatus {
    var title: LocalizedStringResource? {
        switch self {
        case .paused: nil
        case .searching: .statusSearching
        case .reading: .statusReading
        case .moveCloser: .statusMoveCloser
        case .noText: .statusNoText
        }
    }

    var color: Color {
        switch self {
        case .reading: .appSuccess
        case .moveCloser: .appWarning
        case .paused, .searching, .noText: .appTextSecondary
        }
    }

    var outline: AnyShapeStyle {
        switch self {
        case .paused, .searching: AnyShapeStyle(AppGradient.brand)
        case .reading, .moveCloser, .noText: AnyShapeStyle(color)
        }
    }
}
