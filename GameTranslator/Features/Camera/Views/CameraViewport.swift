import SwiftUI

/// Picture, reading box, its state, and the translation beside it.
struct CameraViewport: View {
    let viewModel: CameraViewModel
    @Binding var box: ScanBox
    @Binding var isFullScreen: Bool
    /// Off when the translation has a place of its own.
    var showsTranslation = true
    /// Zoom when the current pinch began.
    @State private var pinchStart: CGFloat?
    @Environment(\.layoutDirection) private var appDirection

    private static let zoomSteps: [CGFloat] = [1, 2, 3]
    private static let controlsHeight: CGFloat = 72

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                picture(in: size)
                ScanBoxView(box: $box, isEditing: viewModel.isEditingBox, status: viewModel.status)
                overlay(in: size)
            }
            .simultaneousGesture(zoomGesture)
        }
        // Drag offsets and frames must mean the same thing in both directions.
        .environment(\.layoutDirection, .leftToRight)
        .overlay(alignment: .top) { controls }
        .background(.black)
        .clipShape(.rect(cornerRadius: isFullScreen ? 0 : AppRadius.large))
        .overlay {
            if !isFullScreen {
                RoundedRectangle(cornerRadius: AppRadius.large).strokeBorder(Color.appOutline, lineWidth: 1)
            }
        }
    }

    @ViewBuilder private func picture(in size: CGSize) -> some View {
        if let session = viewModel.session {
            // Stays below a frozen picture: it is what maps the box to the sensor.
            CameraPreview(session: session, box: box.frame(in: size)) {
                viewModel.setRegion($0, aspectRatio: aspectRatio(in: size))
            }
        }
        if let still = viewModel.stillImage {
            Image(decorative: still, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder private func overlay(in size: CGSize) -> some View {
        if showsTranslation, viewModel.hasResult, !viewModel.isEditingBox {
            let boxFrame = box.frame(in: size)
            let place = OverlayPlacement(
                box: boxFrame, in: size, top: Self.controlsHeight, bottom: isFullScreen ? PlayButton.size + AppSpacing.large * 1.5 : 0
            ).frame
            TranslationOverlay(viewModel: viewModel)
                .environment(\.layoutDirection, appDirection)
                // Hugs the box from whichever side it is on.
                .frame(
                    width: place.width, height: place.height,
                    alignment: place.minY >= boxFrame.midY ? .top : .bottom
                )
                .position(x: place.midX, y: place.midY)
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: AppSpacing.small * 2) {
            AppButton(
                isFullScreen ? .homeExitFullScreen : .homeFullScreen,
                icon: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
            ) {
                withAnimation(.snappy(duration: 0.3)) { isFullScreen.toggle() }
            }
            .buttonStyle(.icon)
            if viewModel.hasTorch {
                AppButton(
                    .cameraTorch, icon: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                    action: viewModel.toggleTorch
                )
                .buttonStyle(.icon)
            }
            Spacer()
            if !viewModel.isFrozen { zoomButtons }
        }
        .padding(AppSpacing.medium)
    }

    private var zoomButtons: some View {
        HStack(spacing: AppSpacing.small) {
            ForEach(Self.zoomSteps, id: \.self, content: zoomButton)
        }
        .padding(AppSpacing.small)
        .background(Color.appSurface.opacity(0.85), in: .capsule)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func zoomButton(_ step: CGFloat) -> some View {
        let isSelected = viewModel.zoom >= step && viewModel.zoom < step + 1
        return Button { viewModel.setZoom(step) } label: {
            Text(verbatim: "\(Int(step))×")
                .font(.subheadline.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .foregroundStyle(isSelected ? Color.white : Color.appTextSecondary)
                .frame(width: 36, height: 36)
                .background { if isSelected { Circle().fill(AppGradient.action) } }
        }
        .accessibilityLabel(Text(.cameraZoom(Int(step))))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard !viewModel.isFrozen else { return }
                let start = pinchStart ?? viewModel.zoom
                pinchStart = start
                viewModel.setZoom(start * value.magnification)
            }
            .onEnded { _ in pinchStart = nil }
    }

    private func aspectRatio(in size: CGSize) -> CGFloat {
        let frame = box.frame(in: size)
        return frame.height > 0 ? frame.width / frame.height : 1
    }
}
