import Foundation
import Testing
@testable import GameTranslator

@MainActor
struct HistoryTests {
    private final class Clock {
        var date = Date(timeIntervalSince1970: 1_000_000)
    }

    private let url = FileManager.default.temporaryDirectory.appending(path: "history-\(UUID().uuidString).json")
    private let settings = InMemorySettingsStore()
    private let clock = Clock()
    private let pair = LanguagePair(source: "en", target: "ar")

    private func makeStore() -> HistoryStore { HistoryStore(fileURL: url, settings: settings, now: { clock.date }) }

    private func add(_ texts: [String], to store: HistoryStore, source: HistoryEntry.Source = .camera) {
        store.record(texts.map { ($0, "ar:\($0)") }, pair: pair, source: source)
    }

    private func originals(_ store: HistoryStore) -> [String] { store.entries.map(\.original) }

    @Test func newestFirstInScreenOrder() {
        let store = makeStore()
        add(["One", "Two"], to: store)
        add(["Three"], to: store)
        #expect(originals(store) == ["Three", "One", "Two"])
    }

    @Test func repeatedTextMovesUp() {
        let store = makeStore()
        add(["One", "Two"], to: store)
        add(["Two"], to: store)
        #expect(originals(store) == ["Two", "One"])
    }

    @Test func survivesRelaunch() {
        add(["One"], to: makeStore())
        #expect(makeStore().entries.map(\.translation) == ["ar:One"])
    }

    @Test func nothingIsKeptWhenTurnedOff() {
        var current = settings.load()
        current.reading.savesHistory = false
        settings.save(current)
        let store = makeStore()
        add(["One"], to: store)
        #expect(store.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func removeAndClear() throws {
        let store = makeStore()
        add(["One", "Two"], to: store)
        store.remove(try #require(store.entries.first).id)
        #expect(originals(makeStore()) == ["Two"])
        store.clear()
        #expect(store.entries.isEmpty && !FileManager.default.fileExists(atPath: url.path))
    }

    @Test func oldestAreDropped() {
        let store = makeStore()
        add((0..<HistoryStore.capacity + 5).map { "Line \($0)" }, to: store)
        #expect(store.entries.count == HistoryStore.capacity)
        #expect(store.entries.first?.original == "Line 0")
    }

    @Test func damagedFileStartsEmpty() throws {
        try Data("broken".utf8).write(to: url)
        #expect(makeStore().entries.isEmpty)
    }

    @Test func groupsByDayAndFilters() throws {
        let store = makeStore()
        add(["Follow the car"], to: store, source: .photo)
        clock.date += 86_400 * 2
        add(["Lose the police"], to: store, source: .camera)
        let viewModel = HistoryViewModel(store: store)
        #expect(viewModel.days.map { $0.entries.map(\.original) } == [["Lose the police"], ["Follow the car"]])
        viewModel.source = .photo
        #expect(viewModel.days.flatMap(\.entries).map(\.original) == ["Follow the car"])
        viewModel.source = nil
        viewModel.query = " ar:lose "
        #expect(viewModel.days.flatMap(\.entries).map(\.original) == ["Lose the police"])
        viewModel.query = "nothing"
        #expect(viewModel.days.isEmpty && !viewModel.isEmpty)
    }
}
