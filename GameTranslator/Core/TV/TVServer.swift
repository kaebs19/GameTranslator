import Foundation
import Network

/// What happened on the network, for the link to act on.
nonisolated enum TVServerEvent: Equatable, Sendable {
    case ready
    case failed
    /// The PIN or the list of TVs may have changed.
    case pairingChanged(pin: String?, tvs: [PairedTV])
    /// TVs that are receiving now.
    case connected(Set<PairedTV.ID>)
}

nonisolated protocol TVServing: Sendable {
    /// Starts listening. The stream ends when the server stops.
    func start(tvs: [PairedTV]) async -> AsyncStream<TVServerEvent>
    func stop() async
    func setPairing(open: Bool) async
    func send(_ message: TVMessage) async
    func remove(_ id: PairedTV.ID) async
}

/// Tiny web server on the home network. Plain HTTP: it carries only lines of game text,
/// and only to TVs that were paired.
/// - `GET /` the receiver page, for any TV with a browser
/// - `POST /pair` trades a PIN for a token
/// - `GET /events?token=` the translations, as server-sent events
actor TVServer: TVServing {
    static let defaultPort: UInt16 = 8787
    private static let maximumConnections = 24
    private static let requestTimeout: Duration = .seconds(10)
    private static let pingInterval: Duration = .seconds(5)
    /// A TV this far behind is gone.
    private static let maximumPending = 64

    private final class Client {
        let connection: NWConnection
        var received = Data()
        var tv: PairedTV.ID?
        var pending = 0
        var timeout: Task<Void, Never>?

        init(_ connection: NWConnection) { self.connection = connection }
    }

    private let queue = DispatchSerialQueue(label: "TVServer")
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    private let port: UInt16
    private let page: Data
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: Client] = [:]
    private var pairing = TVPairing()
    private var latest: TVMessage?
    private var events: AsyncStream<TVServerEvent>.Continuation?
    private var pings: Task<Void, Never>?

    init(port: UInt16 = defaultPort, page: Data) {
        self.port = port
        self.page = page
    }

    // MARK: Control

    func start(tvs: [PairedTV]) -> AsyncStream<TVServerEvent> {
        stop()
        let wasOpen = pairing.pin != nil
        pairing = TVPairing(tvs: tvs)
        if wasOpen { pairing.open() }
        let (stream, continuation) = AsyncStream.makeStream(of: TVServerEvent.self)
        events = continuation
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.prohibitedInterfaceTypes = [.cellular]
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            listener.stateUpdateHandler = { [weak self] state in
                self?.assumeIsolated { $0.listenerDidChange(state) }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.assumeIsolated { $0.accept(connection) }
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            continuation.yield(.failed)
        }
        pings = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pingInterval)
                await self?.ping()
            }
        }
        return stream
    }

    func stop() {
        pings?.cancel()
        listener?.stateUpdateHandler = nil
        listener?.newConnectionHandler = nil
        listener?.cancel()
        listener = nil
        for client in Array(clients.values) { drop(client) }
        latest = nil
        events?.finish()
        events = nil
    }

    func setPairing(open: Bool) {
        if open { pairing.open() } else { pairing.close() }
        reportPairing()
    }

    func send(_ message: TVMessage) {
        guard message != latest else { return }
        latest = message
        broadcast(message.event)
    }

    func remove(_ id: PairedTV.ID) {
        pairing.remove(id)
        for client in clients.values where client.tv == id { drop(client) }
        reportPairing()
    }

    // MARK: Connections

    private func listenerDidChange(_ state: NWListener.State) {
        switch state {
        case .ready: events?.yield(.ready)
        case .failed: events?.yield(.failed)
        default: break
        }
    }

    private func accept(_ connection: NWConnection) {
        guard clients.count < Self.maximumConnections else { return connection.cancel() }
        let client = Client(connection)
        clients[ObjectIdentifier(connection)] = client
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let connection else { return }
            self?.assumeIsolated { $0.connectionDidChange(connection, state) }
        }
        // A connection that never asks for anything must not hold a place.
        client.timeout = Task { [weak self] in
            try? await Task.sleep(for: Self.requestTimeout)
            guard !Task.isCancelled else { return }
            await self?.timeOut(ObjectIdentifier(connection))
        }
        connection.start(queue: queue)
        receive(client)
    }

    private func connectionDidChange(_ connection: NWConnection, _ state: NWConnection.State) {
        switch state {
        case .failed, .cancelled:
            if let client = clients[ObjectIdentifier(connection)] { drop(client) }
        default: break
        }
    }

    private func timeOut(_ id: ObjectIdentifier) {
        if let client = clients[id], client.tv == nil { drop(client) }
    }

    private func drop(_ client: Client) {
        guard clients.removeValue(forKey: ObjectIdentifier(client.connection)) != nil else { return }
        client.timeout?.cancel()
        client.connection.stateUpdateHandler = nil
        client.connection.cancel()
        if client.tv != nil { reportConnected() }
    }

    private func receive(_ client: Client) {
        let id = ObjectIdentifier(client.connection)
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isDone, error in
            self?.assumeIsolated { $0.received(data, isDone: isDone || error != nil, from: id) }
        }
    }

    private func received(_ data: Data?, isDone: Bool, from id: ObjectIdentifier) {
        guard let client = clients[id] else { return }
        // A TV only listens; whatever it sends later is ignored.
        if client.tv != nil { return isDone ? drop(client) : receive(client) }
        client.received += data ?? Data()
        switch HTTPRequest.parse(client.received) {
        case .incomplete: isDone ? drop(client) : receive(client)
        case .invalid: reply(HTTPResponse(status: .badRequest), to: client)
        case .complete(let request): handle(request, from: client)
        }
    }

    // MARK: Requests

    private func handle(_ request: HTTPRequest, from client: Client) {
        switch (request.method, request.path) {
        case ("GET", "/"):
            reply(HTTPResponse(type: "text/html; charset=utf-8", body: page), to: client)
        case ("GET", "/platform.js"):
            // Only the packaged TV apps have one.
            reply(HTTPResponse(type: "text/javascript"), to: client)
        case ("POST", "/pair"):
            reply(pair(request.body), to: client)
        case ("GET", "/events"):
            openStream(token: request.query["token"], for: client)
        default:
            reply(HTTPResponse(status: .notFound), to: client)
        }
    }

    private func pair(_ body: Data) -> HTTPResponse {
        struct Attempt: Decodable { let pin: String; let name: String? }
        guard let attempt = try? JSONDecoder().decode(Attempt.self, from: body) else {
            return HTTPResponse(status: .badRequest)
        }
        let outcome = pairing.pair(pin: attempt.pin, name: attempt.name ?? "")
        reportPairing()
        switch outcome {
        case .paired(let tv):
            return HTTPResponse(type: "application/json", body: Data(#"{"token":"\#(tv.token)"}"#.utf8))
        case .rejected: return HTTPResponse(status: .forbidden)
        case .locked: return HTTPResponse(status: .tooMany)
        }
    }

    private func openStream(token: String?, for client: Client) {
        guard let token, let tv = pairing.tv(token: token) else {
            return reply(HTTPResponse(status: .unauthorized), to: client)
        }
        client.timeout?.cancel()
        client.received = Data()
        // The same TV connecting again replaces its old connection.
        for other in clients.values where other.tv == tv.id { drop(other) }
        client.tv = tv.id
        write(HTTPResponse.eventStreamHead + (latest?.event ?? TVMessage.ping), to: client)
        receive(client)
        reportConnected()
    }

    private func reply(_ response: HTTPResponse, to client: Client) {
        let id = ObjectIdentifier(client.connection)
        client.connection.send(
            content: response.data, contentContext: .finalMessage, isComplete: true,
            completion: .contentProcessed { [weak self] _ in self?.assumeIsolated { $0.finish(id) } }
        )
    }

    private func finish(_ id: ObjectIdentifier) {
        if let client = clients[id] { drop(client) }
    }

    // MARK: Sending

    private func ping() { broadcast(TVMessage.ping) }

    private func broadcast(_ data: Data) {
        for client in Array(clients.values) where client.tv != nil { write(data, to: client) }
    }

    private func write(_ data: Data, to client: Client) {
        guard client.pending < Self.maximumPending else { return drop(client) }
        client.pending += 1
        let id = ObjectIdentifier(client.connection)
        client.connection.send(content: data, completion: .contentProcessed { [weak self] error in
            self?.assumeIsolated { $0.wrote(id, failed: error != nil) }
        })
    }

    private func wrote(_ id: ObjectIdentifier, failed: Bool) {
        guard let client = clients[id] else { return }
        client.pending -= 1
        if failed { drop(client) }
    }

    private func reportPairing() {
        events?.yield(.pairingChanged(pin: pairing.pin, tvs: pairing.tvs))
    }

    private func reportConnected() {
        events?.yield(.connected(Set(clients.values.compactMap(\.tv))))
    }
}
