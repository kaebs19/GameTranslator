import Foundation
import Testing
@testable import GameTranslator

@MainActor
struct InstantTranslateViewModelTests {
    private let translator = StubTranslator()
    private let settings = InMemorySettingsStore()
    private let history = StubHistory()

    private func makeViewModel(
        texts: [String] = ["Follow the car", "12:30"], photos: StubPhotoLibrary = StubPhotoLibrary()
    ) -> InstantTranslateViewModel {
        InstantTranslateViewModel(
            translator: translator, recognizer: StubRecognizer(texts: texts), photos: photos, settings: settings,
            history: history
        )
    }

    private func result(of viewModel: InstantTranslateViewModel) async throws -> TranslationResult {
        #expect(try await eventually { viewModel.result != nil })
        return try #require(viewModel.result)
    }

    private func expectFailure(_ error: AppError, in viewModel: InstantTranslateViewModel) async throws {
        #expect(try await eventually { viewModel.error == error })
    }

    @Test func translatesTextAndSkipsNumbers() async throws {
        let viewModel = makeViewModel()
        let data = try TestImage.png(lines: ["x"])
        viewModel.translate { data }
        let rows = try await result(of: viewModel).rows
        #expect(rows.map(\.original) == ["Follow the car"])
        #expect(rows.map(\.translation) == ["ar:Follow the car"])
        #expect(translator.requests == [["Follow the car"]])
        #expect(history.recorded.map(\.original) == ["Follow the car"])
        #expect(history.recorded.first?.source == .photo)
    }

    @Test func latestScreenshotComesFromThePhotoLibrary() async throws {
        let photos = StubPhotoLibrary(latest: .success(try TestImage.png(lines: ["x"])))
        let viewModel = makeViewModel(photos: photos)
        viewModel.handle(.latestScreenshot)
        _ = try await result(of: viewModel)
    }

    @Test func photoLibraryErrorIsShown() async throws {
        let viewModel = makeViewModel(photos: StubPhotoLibrary(latest: .failure(.photoAccessDenied)))
        viewModel.translateLatestScreenshot()
        try await expectFailure(.photoAccessDenied, in: viewModel)
        #expect(!viewModel.canRetry)
    }

    @Test func translatorErrorCanBeRetried() async throws {
        let viewModel = makeViewModel()
        let working = translator.translate
        translator.translate = { _ in throw AppError.unsupportedLanguages }
        let data = try TestImage.png(lines: ["x"])
        viewModel.translate { data }
        try await expectFailure(.unsupportedLanguages, in: viewModel)
        #expect(viewModel.canRetry)
        translator.translate = working
        viewModel.retry()
        _ = try await result(of: viewModel)
    }

    @Test func lateResultAfterResetIsDropped() async throws {
        let viewModel = makeViewModel()
        var finish: CheckedContinuation<[String: String], any Error>?
        translator.translate = { _ in try await withCheckedThrowingContinuation { finish = $0 } }
        let data = try TestImage.png(lines: ["x"])
        viewModel.translate { data }
        #expect(try await eventually { finish != nil })
        viewModel.reset()
        finish?.resume(returning: ["Follow the car": "late"])
        try await Task.sleep(for: .milliseconds(300))
        #expect(viewModel.isIdle)
        #expect(!viewModel.canRetry)
    }

    @Test func imageWithoutTextFails() async throws {
        let viewModel = makeViewModel(texts: ["12:30"])
        let data = try TestImage.png(lines: ["x"])
        viewModel.translate { data }
        try await expectFailure(.noText, in: viewModel)
        #expect(translator.requests.isEmpty)
    }

    @Test func brokenImageFails() async throws {
        let viewModel = makeViewModel()
        viewModel.translate { Data("not an image".utf8) }
        try await expectFailure(.unreadableImage, in: viewModel)
    }

    @Test func sameLanguageFails() async throws {
        settings.save(AppSettings(source: .english, target: .english))
        let viewModel = makeViewModel()
        let data = try TestImage.png(lines: ["x"])
        viewModel.translate { data }
        try await expectFailure(.sameLanguage, in: viewModel)
    }

    @Test func retranslatesOnlyWhenSettingsChanged() async throws {
        let viewModel = makeViewModel()
        let data = try TestImage.png(lines: ["x"])
        viewModel.translate { data }
        _ = try await result(of: viewModel)
        viewModel.settingsDidClose()
        #expect(viewModel.result != nil)
        var longerList = settings.load()
        longerList.add(AppLanguage(code: "nl"))
        settings.save(longerList)
        viewModel.settingsDidClose()
        #expect(viewModel.result != nil)
        settings.save(AppSettings(source: .english, target: AppLanguage(code: "fr")))
        viewModel.settingsDidClose()
        _ = try await result(of: viewModel)
        #expect(translator.requests.count == 2)
    }

    @Test func readsRealScreenshotEndToEnd() async throws {
        let viewModel = InstantTranslateViewModel(
            translator: translator, recognizer: OCRService(), photos: StubPhotoLibrary(), settings: settings,
            history: history
        )
        let data = try TestImage.png(lines: ["FOLLOW THE CAR", "Press the button"])
        viewModel.translate { data }
        #expect(try await result(of: viewModel).rows.map(\.original) == ["FOLLOW THE CAR", "Press the button"])
    }
}

private extension InstantTranslateViewModel {
    var result: TranslationResult? {
        if case .finished(let result) = state { result } else { nil }
    }

    var error: AppError? {
        if case .failed(let error) = state { error } else { nil }
    }
}
