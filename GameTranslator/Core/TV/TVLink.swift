import Foundation
import Observation

/// Where translations go besides this phone's screen.
protocol TVPresenting {
    func show(_ lines: [SharedTranslation.Line], target: AppLanguage)
}

/// Keeps the server in step with the app: on while the user wants it and the app is open.
/// iOS stops apps in the background, so TVs are only served while this one is on screen.
@Observable
final class TVLink: TVPresenting {
    enum State: Equatable {
        case off, starting, ready
        case failed(AppError)
    }

    private(set) var state = State.off
    private(set) var pairingCode: PairingCode?
    private(set) var tvs: [PairedTV]
    private(set) var connected: Set<PairedTV.ID> = []
    private(set) var address: PhoneAddress?
    var isEnabled: Bool { settings.load().tv.isEnabled }

    private let server: any TVServing
    private let addresses: any LocalAddressProviding
    private let keys: any KeyStoring
    private let settings: any SettingsStoring
    @ObservationIgnored private var listening: Task<Void, Never>?
    @ObservationIgnored private var isAppOpen = false
    @ObservationIgnored private var isPairing = false
    @ObservationIgnored private var lines: [SharedTranslation.Line] = []
    @ObservationIgnored private var target = AppLanguage.arabic
    /// Commands reach the server in the order they were given.
    @ObservationIgnored private var lastCommand: Task<Void, Never>?

    init(
        server: any TVServing, addresses: any LocalAddressProviding, keys: any KeyStoring,
        settings: any SettingsStoring
    ) {
        self.server = server
        self.addresses = addresses
        self.keys = keys
        self.settings = settings
        tvs = Self.loadTVs(keys)
    }

    // MARK: Lifecycle

    func setEnabled(_ isEnabled: Bool) {
        var current = settings.load()
        current.tv.isEnabled = isEnabled
        settings.save(current)
        update()
    }

    func appDidChange(isOpen: Bool) {
        isAppOpen = isOpen
        update()
    }

    func retry() {
        stop()
        update()
    }

    private func update() {
        let shouldRun = isEnabled && isAppOpen
        if shouldRun, listening == nil { start() }
        if !shouldRun { stop() }
    }

    private func start() {
        address = addresses.current()
        guard address != nil else { return state = .failed(.noLocalNetwork) }
        state = .starting
        let starting = Task { [server, lastCommand, tvs] in
            await lastCommand?.value
            return await server.start(tvs: tvs)
        }
        lastCommand = Task { [server, isPairing] in
            _ = await starting.value
            await server.setPairing(open: isPairing)
        }
        listening = Task { [weak self] in
            for await event in await starting.value {
                guard !Task.isCancelled else { return }
                self?.handle(event)
            }
        }
        sendLines()
    }

    private func stop() {
        if listening != nil {
            listening?.cancel()
            listening = nil
            command { await $0.stop() }
        }
        state = .off
        connected = []
        pairingCode = nil
    }

    private func handle(_ event: TVServerEvent) {
        switch event {
        case .ready:
            state = .ready
        case .failed:
            stop()
            state = .failed(.tvServerFailed)
        case .pairingChanged(let pin, let newTVs):
            if let pin, let address { pairingCode = PairingCode(address: address, pin: pin) } else { pairingCode = nil }
            guard newTVs != tvs else { return }
            tvs = newTVs
            saveTVs()
        case .connected(let ids):
            connected = ids
        }
    }

    // MARK: Pairing

    /// The PIN is only accepted while the user sees it.
    func setPairing(open: Bool) {
        isPairing = open
        if !open { pairingCode = nil }
        guard listening != nil else { return }
        command { await $0.setPairing(open: open) }
    }

    func forget(_ id: PairedTV.ID) {
        tvs.removeAll { $0.id == id }
        connected.remove(id)
        saveTVs()
        command { await $0.remove(id) }
    }

    // MARK: Showing

    func show(_ lines: [SharedTranslation.Line], target: AppLanguage) {
        self.lines = lines
        self.target = target
        sendLines()
    }

    /// Position, size or original text changed.
    func styleDidChange() { sendLines() }

    private func sendLines() {
        guard listening != nil else { return }
        let message = TVMessage(lines: lines, target: target, settings: settings.load().tv)
        command { await $0.send(message) }
    }

    private func command(_ body: @escaping @Sendable (any TVServing) async -> Void) {
        lastCommand = Task { [server, lastCommand] in
            await lastCommand?.value
            await body(server)
        }
    }

    // MARK: Storage

    /// Tokens let a TV receive, so they are kept like keys.
    private func saveTVs() {
        guard !tvs.isEmpty, let data = try? JSONEncoder().encode(tvs) else { return keys.remove() }
        try? keys.save(String(decoding: data, as: UTF8.self))
    }

    private static func loadTVs(_ keys: any KeyStoring) -> [PairedTV] {
        guard let text = keys.load() else { return [] }
        return (try? JSONDecoder().decode([PairedTV].self, from: Data(text.utf8))) ?? []
    }
}
