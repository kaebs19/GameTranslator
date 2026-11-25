import Foundation
import Testing
@testable import GameTranslator

@MainActor
struct CloudSettingsViewModelTests {
    private let store = InMemorySettingsStore()
    private let keys = StubKeyStore()
    private let cloud = StubCloud()

    private func makeViewModel() -> CloudSettingsViewModel {
        CloudSettingsViewModel(store: store, keys: keys, translator: cloud)
    }

    @Test func isOffByDefault() {
        #expect(!store.load().usesCloudTranslation)
        #expect(!makeViewModel().isEnabled)
    }

    @Test func workingKeyIsCheckedWithAFixedWordThenSaved() async {
        let viewModel = makeViewModel()
        viewModel.enteredKey = "  abc \n"
        await viewModel.enable()
        #expect(viewModel.isEnabled && store.load().usesCloudTranslation)
        #expect(keys.key == "abc")
        #expect(viewModel.enteredKey.isEmpty)
        #expect(cloud.requests.map(\.texts) == [["Hello"]])
    }

    @Test func rejectedKeyIsNotSaved() async {
        cloud.error = .cloudKeyRejected
        let viewModel = makeViewModel()
        viewModel.enteredKey = "abc"
        await viewModel.enable()
        #expect(viewModel.error == .cloudKeyRejected)
        #expect(!viewModel.isEnabled && keys.key == nil && !store.load().usesCloudTranslation)
    }

    @Test func keychainFailureKeepsItOff() async {
        keys.fails = true
        let viewModel = makeViewModel()
        viewModel.enteredKey = "abc"
        await viewModel.enable()
        #expect(viewModel.error == .keyNotSaved)
        #expect(!store.load().usesCloudTranslation)
    }

    @Test func emptyKeyDoesNothing() async {
        let viewModel = makeViewModel()
        viewModel.enteredKey = "   "
        await viewModel.enable()
        #expect(cloud.requests.isEmpty)
    }

    @Test func turningOffDeletesTheKey() async {
        let viewModel = makeViewModel()
        viewModel.enteredKey = "abc"
        await viewModel.enable()
        viewModel.disable()
        #expect(keys.key == nil && !viewModel.isEnabled && !store.load().usesCloudTranslation)
    }
}
