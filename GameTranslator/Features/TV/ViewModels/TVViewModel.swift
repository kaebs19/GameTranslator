import Foundation
import Observation

@Observable
final class TVViewModel {
    private(set) var isEnabled: Bool
    var look: TVSettings {
        didSet {
            guard look != oldValue else { return }
            save()
        }
    }

    private let link: TVLink
    private let store: any SettingsStoring

    init(link: TVLink, store: any SettingsStoring) {
        self.link = link
        self.store = store
        look = store.load().tv
        isEnabled = link.isEnabled
    }

    var state: TVLink.State { link.state }
    var pairingCode: PairingCode? { link.pairingCode }
    var tvs: [PairedTV] { link.tvs }

    /// For a browser, which cannot read the address out of the code.
    var webAddress: String? {
        guard state == .ready else { return nil }
        return link.address.map { "http://\($0):\(TVServer.defaultPort)" }
    }

    var canTest: Bool { !link.connected.isEmpty }

    func isConnected(_ tv: PairedTV) -> Bool { link.connected.contains(tv.id) }

    func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
        link.setEnabled(isEnabled)
    }

    func setVisible(_ isVisible: Bool) { link.setPairing(open: isVisible) }

    func retry() { link.retry() }

    func forget(_ tv: PairedTV) { link.forget(tv.id) }

    func sendTest(_ sample: String) {
        link.show([.init(original: "Follow the car", translation: sample)], target: store.load().target)
    }

    /// Only the look: whether it is on belongs to the link.
    private func save() {
        var settings = store.load()
        let isEnabled = settings.tv.isEnabled
        settings.tv = look
        settings.tv.isEnabled = isEnabled
        store.save(settings)
        link.styleDidChange()
    }
}
