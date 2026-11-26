import CoreGraphics
import Foundation
import Observation

/// Walks through remote play one step at a time and keeps the next step closed until this one is done.
@Observable
final class RemotePlayGuideViewModel: Identifiable {
    let id = UUID()

    private(set) var step = RemotePlayStep.console
    private(set) var progress = RemotePlayProgress()
    /// The code to type on the TV, from the server.
    private(set) var code: String?
    private(set) var tvs: [ServerTV] = []
    private(set) var error: Bool = false
    /// Always kept usable.
    var region: CGRect {
        get { storedRegion }
        set { storedRegion = RemotePlaySettings.clamped(newValue) }
    }
    private var storedRegion: CGRect

    private let links: any ServerTVLinking
    private let settings: any SettingsStoring
    private let lineCount: () -> Int
    private let isBroadcasting: () -> Bool
    @ObservationIgnored private var linesAtStart = 0
    @ObservationIgnored private var watching: Task<Void, Never>?

    init(
        links: any ServerTVLinking, settings: any SettingsStoring,
        lineCount: @escaping () -> Int, isBroadcasting: @escaping () -> Bool
    ) {
        self.links = links
        self.settings = settings
        self.lineCount = lineCount
        self.isBroadcasting = isBroadcasting
        storedRegion = settings.load().remotePlay.region
    }

    var number: Int { step.rawValue + 1 }
    var count: Int { RemotePlayStep.allCases.count }
    var canGoBack: Bool { step != .console && step != .done }
    var canContinue: Bool { progress.isDone(step) }
    var isLast: Bool { step == .done }

    func confirm(_ isDone: Bool = true) {
        if isDone { progress.confirmed.insert(step) } else { progress.confirmed.remove(step) }
        if step == .region, isDone { saveRegion() }
    }

    func next() {
        guard canContinue, let next = RemotePlayStep(rawValue: step.rawValue + 1) else { return }
        step = next
        didEnter()
    }

    func back() {
        guard canGoBack, let previous = RemotePlayStep(rawValue: step.rawValue - 1) else { return }
        step = previous
        didEnter()
    }

    /// Called by the view on appear and while it is open.
    func didEnter() {
        watching?.cancel()
        switch step {
        case .pair:
            watching = Task { [weak self] in await self?.watchPairing() }
        case .broadcast:
            // From here the broadcast sends to the TV.
            var current = settings.load()
            current.remotePlay.sendsToTV = true
            settings.save(current)
            watching = Self.repeating { [weak self] in self?.refreshBroadcast() }
        case .play:
            linesAtStart = lineCount()
            watching = Self.repeating { [weak self] in self?.refreshLines() }
        default: break
        }
    }

    func stop() { watching?.cancel() }

    func setRegionPreset(_ rect: CGRect) { region = rect }

    // MARK: Watching

    private func watchPairing() async {
        if code == nil || !tvs.isEmpty { await requestCode() }
        while !Task.isCancelled {
            await refreshTVs()
            try? await Task.sleep(for: .seconds(2))
        }
    }

    func requestCode() async {
        do {
            code = try await links.newTVCode()
            error = false
        } catch {
            self.error = true
        }
    }

    private func refreshTVs() async {
        guard let list = try? await links.tvs() else { return }
        tvs = list
        progress.isTVConnected = list.contains(where: \.isConnected)
    }

    private func refreshBroadcast() { progress.isBroadcasting = isBroadcasting() }

    private func refreshLines() { progress.linesRead = max(0, lineCount() - linesAtStart) }

    /// Checks twice a second until cancelled.
    private static func repeating(_ refresh: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        Task { @MainActor in
            while !Task.isCancelled {
                refresh()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func saveRegion() {
        var current = settings.load()
        current.remotePlay.region = region
        settings.save(current)
    }
}
