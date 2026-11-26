import SwiftUI
import UniformTypeIdentifiers

/// Share as text or as a picture.
struct ShareTranslationMenu<Label: View>: View {
    let shared: SharedTranslation
    @ViewBuilder let label: Label

    var body: some View {
        Menu {
            ShareTranslationItems(shared: shared)
        } label: {
            label
        }
    }
}

/// The two choices, for use inside another menu.
struct ShareTranslationItems: View {
    let shared: SharedTranslation

    var body: some View {
        ShareLink(item: shared.text) {
            AppLabel(.shareAsText, icon: "text.alignright")
        }
        ShareLink(
            item: TranslationPicture(shared: shared),
            preview: SharePreview(shared.title, image: Image(.launchLogo))
        ) {
            AppLabel(.shareAsImage, icon: "photo")
        }
    }
}

/// Drawn only when something actually asks for the picture.
nonisolated struct TranslationPicture: Transferable {
    let shared: SharedTranslation

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { picture in
            try await ShareCardRenderer.png(of: picture.shared)
        }
        .suggestedFileName("translation.png")
    }
}

enum ShareCardRenderer {
    static func png(of shared: SharedTranslation) throws -> Data {
        let renderer = ImageRenderer(content: ShareCard(shared: shared))
        renderer.scale = 3
        renderer.isOpaque = true
        guard let data = renderer.uiImage?.pngData() else { throw AppError.unreadableImage }
        return data
    }
}
