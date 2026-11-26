import Foundation

/// Where the user is in setting up a TV, one step per screen.
struct TVGuide: Equatable, Identifiable {
    /// A new guide each time it opens.
    let id = UUID()

    enum Step: Equatable {
        case choose
        // Google TV and Android TV.
        case install, download, open, pair
        // Any browser.
        case address, browserPair
        // Samsung and LG apps are not available yet.
        case unavailable
        case test, done
    }

    /// Typed into Downloader on the TV, so kept short.
    static let downloadAddress = "subgg.app/tv.apk"

    private(set) var kind: TVKind?
    private(set) var index = 0

    init(kind: TVKind? = nil) {
        self.kind = kind
        index = kind == nil ? 0 : 1
    }

    var steps: [Step] {
        let rest: [Step] = switch kind {
        case .android: [.install, .download, .open, .pair, .test, .done]
        case .browser: [.address, .browserPair, .test, .done]
        case .samsung, .lg: [.unavailable]
        case nil: []
        }
        return [.choose] + rest
    }

    var step: Step { steps[min(index, steps.count - 1)] }
    var number: Int { index + 1 }
    var count: Int { max(steps.count, 2) }
    var canGoBack: Bool { index > 0 }
    var isLast: Bool { index == steps.count - 1 && kind != nil }

    /// Steps that wait for the TV hold the way forward until it has connected.
    func canContinue(isConnected: Bool) -> Bool {
        switch step {
        case .choose: kind != nil
        case .pair, .browserPair: isConnected
        default: true
        }
    }

    mutating func choose(_ kind: TVKind) {
        self.kind = kind
        index = 1
    }

    mutating func next() {
        if index < steps.count - 1 { index += 1 }
    }

    mutating func back() {
        if index > 0 { index -= 1 }
    }
}
