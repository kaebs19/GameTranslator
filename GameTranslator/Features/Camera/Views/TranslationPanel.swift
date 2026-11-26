import SwiftUI

/// Fixed place for the translation below the camera. Its height never changes with the text,
/// because that would resize the picture and move the box.
struct TranslationPanel: View {
    let viewModel: CameraViewModel

    var body: some View {
        if viewModel.hasResult {
            TranslationOverlay(viewModel: viewModel, fills: true)
        } else {
            TranslationPlaceholder(isTranslating: viewModel.isTranslating || viewModel.isFrozen, fills: true)
        }
    }
}
