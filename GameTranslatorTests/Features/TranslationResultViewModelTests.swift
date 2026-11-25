import Testing
import UIKit
@testable import GameTranslator

@MainActor
struct TranslationResultViewModelTests {
    private func makeResult() throws -> TranslationResult {
        let image = try #require(TestImage.make(lines: ["x"]))
        return TranslationResult(image: UIImage(cgImage: image), rows: [
            .init(id: UUID(), original: "Go", translation: "اذهب"), .init(id: UUID(), original: "Stop", translation: nil)
        ])
    }

    @Test func savesOnce() async throws {
        let photos = StubPhotoLibrary()
        let viewModel = TranslationResultViewModel(result: try makeResult(), photos: photos)
        await viewModel.save()
        await viewModel.save()
        #expect(viewModel.saveState == .saved)
        #expect(photos.saved.count == 1)
    }

    @Test func failedSaveShowsErrorAndCanBeRepeated() async throws {
        let photos = StubPhotoLibrary(saveError: .photoAccessDenied)
        let viewModel = TranslationResultViewModel(result: try makeResult(), photos: photos)
        await viewModel.save()
        #expect(viewModel.saveError == .photoAccessDenied)
        #expect(viewModel.saveState == .ready)
        await viewModel.save()
        #expect(viewModel.saveState == .saved)
    }

    @Test func translatedTextSkipsUntranslatedRows() throws {
        #expect(try makeResult().translatedText == "اذهب")
    }
}
