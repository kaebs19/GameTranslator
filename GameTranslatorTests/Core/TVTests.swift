import Foundation
import Network
import Testing
@testable import GameTranslator

struct PairingCodeTests {
    @Test(arguments: [
        ("192.168.1.49", "1003054821"),
        ("192.168.255.255", "1655354821"),
        ("172.20.10.1", "202647054821"),
        ("10.0.0.7", "3000000074821"),
        ("100.64.0.1", "416819159054821")
    ])
    func encodesTheAddressAndThePIN(address: String, digits: String) throws {
        let code = PairingCode(address: try #require(PhoneAddress(address)), pin: "4821")
        #expect(code.digits == digits)
        #expect(PairingCode(digits: digits) == code)
    }

    @Test(arguments: ["", "1", "0003054821", "5003054821", "100305482", "10030548211", "1999994821", "1abcde4821"])
    func refusesOtherDigits(digits: String) {
        #expect(PairingCode(digits: digits) == nil)
    }

    @Test(arguments: ["", "1.2.3", "1.2.3.256", "1.2.3.4.5", "a.b.c.d"])
    func refusesOtherAddresses(text: String) {
        #expect(PhoneAddress(text) == nil)
    }
}

struct TVPairingTests {
    private func makePairing() -> TVPairing { TVPairing { "1234" } }

    @Test func pinOnlyWorksWhilePairingIsOpen() {
        var pairing = makePairing()
        #expect(pairing.pair(pin: "1234", name: "TV") == .rejected)
        pairing.open()
        guard case .paired(let tv) = pairing.pair(pin: "1234", name: " Living\nRoom ") else {
            Issue.record("Not paired")
            return
        }
        #expect(tv.name == "LivingRoom" && tv.token.count == 64)
        #expect(pairing.tv(token: tv.token) == tv && pairing.tv(token: "") == nil)
        pairing.close()
        #expect(pairing.pair(pin: "1234", name: "TV") == .rejected)
    }

    @Test func wrongPINsLockPairingAndReopeningDoesNotHelp() {
        var pairing = makePairing()
        let now = Date.now
        for _ in 1..<TVPairing.maximumFailures {
            pairing.open()
            #expect(pairing.pair(pin: "0000", name: "", now: now) == .rejected)
        }
        #expect(pairing.pair(pin: "0000", name: "", now: now) == .locked)
        pairing.open()
        #expect(pairing.pair(pin: "1234", name: "", now: now) == .locked)
        let later = now.addingTimeInterval(TVPairing.lockDuration + 1)
        guard case .paired = pairing.pair(pin: "1234", name: "", now: later) else {
            Issue.record("Still locked")
            return
        }
    }

    @Test func oldestTVMakesRoomAndRemovedTVLosesAccess() {
        var pairing = makePairing()
        pairing.open()
        for index in 0...TVPairing.maximumTVs { _ = pairing.pair(pin: "1234", name: "\(index)") }
        #expect(pairing.tvs.count == TVPairing.maximumTVs && pairing.tvs.first?.name == "1")
        let tv = pairing.tvs[0]
        pairing.remove(tv.id)
        #expect(pairing.tv(token: tv.token) == nil)
    }
}

struct HTTPRequestTests {
    private func parse(_ text: String) -> HTTPRequest.Parsing { HTTPRequest.parse(Data(text.utf8)) }

    @Test func readsQueryAndBody() {
        #expect(parse("POST /pair?a=b%20c HTTP/1.1\r\nContent-Length: 2\r\n\r\nhi") == .complete(
            HTTPRequest(method: "POST", path: "/pair", query: ["a": "b c"], body: Data("hi".utf8))
        ))
    }

    @Test func waitsForTheRest() {
        #expect(parse("GET / HTTP/1.1\r\n") == .incomplete)
        #expect(parse("POST / HTTP/1.1\r\nContent-Length: 5\r\n\r\nhi") == .incomplete)
    }

    @Test(arguments: [
        "nonsense\r\n\r\n", "GET x HTTP/1.1\r\n\r\n", "GET / FTP\r\n\r\n",
        "POST / HTTP/1.1\r\nContent-Length: -1\r\n\r\n", "POST / HTTP/1.1\r\nContent-Length: 99999999\r\n\r\n"
    ])
    func refusesNonsense(text: String) {
        #expect(parse(text) == .invalid)
    }

    @Test func refusesEndlessHeaders() {
        #expect(HTTPRequest.parse(Data(repeating: 65, count: HTTPRequest.maximumSize + 1)) == .invalid)
    }
}

struct TVMessageTests {
    @Test func originalIsSentOnlyWhenWanted() throws {
        let lines = [SharedTranslation.Line(original: "Hi\nthere", translation: "أهلًا\nبك")]
        var settings = TVSettings()
        let plain = TVMessage(lines: lines, target: .arabic, settings: settings)
        #expect(plain.isRTL && plain.position == .top && plain.lines[0].original == nil)
        settings.showsOriginal = true
        settings.position = .bottom
        let full = TVMessage(lines: lines, target: .english, settings: settings)
        #expect(!full.isRTL && full.lines[0].original == "Hi\nthere")
        let event = String(decoding: full.event, as: UTF8.self)
        // A line break would end the event early.
        #expect(event.hasPrefix("data: {") && event.hasSuffix("}\n\n"))
        #expect(event.dropLast(2).contains("\n") == false)
    }
}

/// Over real sockets, on ports other suites do not use.
@MainActor
struct TVServerTests {
    private static let page = Data("<html>page</html>".utf8)

    private func request(_ port: UInt16, _ path: String, body: String? = nil) async throws -> (Int, String) {
        var request = URLRequest(url: try #require(URL(string: "http://127.0.0.1:\(port)\(path)")))
        if let body {
            request.httpMethod = "POST"
            request.httpBody = Data(body.utf8)
        }
        let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, String(decoding: data, as: UTF8.self))
    }

    private final class Events {
        var isReady = false
        var pin: String?
        var tvs: [PairedTV] = []
        var connected: Set<PairedTV.ID> = []
    }

    private func start(_ server: TVServer, tvs: [PairedTV] = []) async throws -> Events {
        let events = Events()
        let stream = await server.start(tvs: tvs)
        Task {
            for await event in stream {
                switch event {
                case .ready: events.isReady = true
                case .failed: break
                case .pairingChanged(let pin, let tvs): (events.pin, events.tvs) = (pin, tvs)
                case .connected(let ids): events.connected = ids
                }
            }
        }
        #expect(try await eventually { events.isReady })
        return events
    }

    @Test func servesThePageAndRefusesTheRest() async throws {
        let server = TVServer(port: 18787, page: Self.page)
        _ = try await start(server)
        #expect(try await request(18787, "/") == (200, "<html>page</html>"))
        #expect(try await request(18787, "/platform.js") == (200, ""))
        #expect(try await request(18787, "/other").0 == 404)
        #expect(try await request(18787, "/events?token=x").0 == 401)
        #expect(try await request(18787, "/pair", body: #"{"pin":"0000"}"#).0 == 403)
        #expect(try await request(18787, "/pair", body: "?").0 == 400)
        await server.stop()
    }

    @Test func pairsThenStreamsTranslations() async throws {
        let server = TVServer(port: 18788, page: Self.page)
        let events = try await start(server)
        await server.setPairing(open: true)
        #expect(try await eventually { events.pin != nil })
        let pin = try #require(events.pin)
        let (status, answer) = try await request(18788, "/pair", body: #"{"pin":"\#(pin)","name":"Samsung TV"}"#)
        #expect(status == 200)
        #expect(try await eventually { events.tvs.first?.name == "Samsung TV" })
        #expect(events.pin != pin)
        let tv = try #require(events.tvs.first)
        #expect(answer.contains(tv.token))

        let received = Received()
        let url = try #require(URL(string: "http://127.0.0.1:18788/events?token=\(tv.token)"))
        let reading = Task {
            let (bytes, _) = try await URLSession(configuration: .ephemeral).bytes(from: url)
            for try await line in bytes.lines { received.lines.append(line) }
            received.isDone = true
        }
        #expect(try await eventually { events.connected == [tv.id] })
        let line = SharedTranslation.Line(original: "Run", translation: "اركض")
        await server.send(TVMessage(lines: [line], target: .arabic, settings: TVSettings()))
        #expect(try await eventually { received.lines.contains { $0.contains("اركض") } })

        await server.remove(tv.id)
        #expect(try await eventually { events.connected.isEmpty && events.tvs.isEmpty })
        #expect(try await request(18788, "/events?token=\(tv.token)").0 == 401)
        reading.cancel()
        await server.stop()
    }

    @MainActor private final class Received {
        var lines: [String] = []
        var isDone = false
    }

    @Test func startsAgainOnTheSamePort() async throws {
        let server = TVServer(port: 18789, page: Self.page)
        _ = try await start(server)
        _ = try await request(18789, "/")
        await server.stop()
        _ = try await start(server)
        #expect(try await request(18789, "/").0 == 200)
        await server.stop()
    }
}

@MainActor
struct TVLinkTests {
    private let server = StubTVServer()
    private let keys = StubKeyStore()
    private let settings = InMemorySettingsStore()

    private struct Address: LocalAddressProviding {
        var value = PhoneAddress("192.168.1.49")
        func current() -> PhoneAddress? { value }
    }

    private func makeLink(address: Address = Address()) -> TVLink {
        TVLink(server: server, addresses: address, keys: keys, settings: settings)
    }

    @Test func offByDefault() async throws {
        let link = makeLink()
        link.appDidChange(isOpen: true)
        link.show([.init(original: "a", translation: "b")], target: .arabic)
        try await Task.sleep(for: .milliseconds(50))
        #expect(link.state == .off)
        #expect(server.log.isEmpty)
    }

    @Test func runsOnlyWhileTheAppIsOpen() async throws {
        let link = makeLink()
        link.setEnabled(true)
        #expect(link.state == .off)
        link.appDidChange(isOpen: true)
        await server.wait(for: "start")
        server.report(.ready)
        #expect(try await eventually { link.state == .ready })
        link.appDidChange(isOpen: false)
        #expect(link.state == .off)
        await server.wait(for: "stop")
    }

    @Test func noNetworkIsExplained() {
        let link = makeLink(address: Address(value: nil))
        link.setEnabled(true)
        link.appDidChange(isOpen: true)
        #expect(link.state == .failed(.noLocalNetwork))
    }

    @Test func showsTheCodeAndRemembersTVs() async throws {
        let link = makeLink()
        link.setPairing(open: true)
        link.setEnabled(true)
        link.appDidChange(isOpen: true)
        await server.wait(for: "pairing true")
        let tv = PairedTV(id: UUID(), name: "TV", token: "abc")
        server.report(.pairingChanged(pin: "4821", tvs: [tv]))
        #expect(try await eventually { link.pairingCode?.digits == "1003054821" })
        #expect(makeLink().tvs == [tv])
        link.forget(tv.id)
        await server.wait(for: "remove")
        #expect(link.tvs.isEmpty && keys.key == nil)
    }

    @Test func styleChangesResendTheLine() async throws {
        let link = makeLink()
        link.setEnabled(true)
        link.appDidChange(isOpen: true)
        link.show([.init(original: "Run", translation: "اركض")], target: .arabic)
        await server.wait(for: "top اركض")
        var current = settings.load()
        current.tv.position = .bottom
        settings.save(current)
        link.styleDidChange()
        await server.wait(for: "bottom اركض")
    }

    @Test func viewModelKeepsPowerAndLookApart() {
        let link = makeLink()
        let viewModel = TVViewModel(link: link, store: settings)
        viewModel.setEnabled(true)
        viewModel.look.textSize = .large
        #expect(settings.load().tv.isEnabled && settings.load().tv.textSize == .large)
        viewModel.setEnabled(false)
        #expect(!settings.load().tv.isEnabled && settings.load().tv.textSize == .large)
    }
}

@MainActor
private final class StubTVServer: TVServing {
    private(set) var log: [String] = []
    private var events: AsyncStream<TVServerEvent>.Continuation?

    func start(tvs: [PairedTV]) -> AsyncStream<TVServerEvent> {
        log.append("start")
        let (stream, continuation) = AsyncStream.makeStream(of: TVServerEvent.self)
        events = continuation
        return stream
    }

    func stop() {
        log.append("stop")
        events?.finish()
    }

    func setPairing(open: Bool) { log.append("pairing \(open)") }
    func send(_ message: TVMessage) {
        log.append("\(message.position.rawValue) \(message.lines.first?.text ?? "")")
    }
    func remove(_ id: PairedTV.ID) { log.append("remove") }
    func report(_ event: TVServerEvent) { events?.yield(event) }

    func wait(for entry: String) async {
        for _ in 0..<400 where !log.contains(entry) { try? await Task.sleep(for: .milliseconds(25)) }
        #expect(log.contains(entry))
    }
}
