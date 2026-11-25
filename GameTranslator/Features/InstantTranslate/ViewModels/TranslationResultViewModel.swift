import Observation
import UIKit

@Observable
final class TranslationResultViewModel {
    enum SaveState { case ready, saving, saved }

    let result: TranslationResult
    private(set) var saveState = SaveState.ready
    var saveError: AppError?
    private let photos: any PhotoLibraryProviding

    init(result: TranslationResult, photos: any PhotoLibraryProviding) {
        self.result = result
        self.photos = photos
    }

    func save() async {
        guard saveState == .ready, let data = result.image.pngData() else { return }
        saveState = .saving
        do {
            try await photos.save(data)
            saveState = .saved
        } catch {
            saveState = .ready
            saveError = AppError(error)
        }
    }
}
