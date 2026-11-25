import Foundation

/// Hands recognized lines from the extension to the app through the App Group.
///
/// Each batch is its own atomically written file that the reader deletes, so the two
/// processes never need a lock and no text stays on disk once the app has read it.
nonisolated struct LiveChannel: Sendable {
    private let directory: URL
    private let maxPending: Int

    init(directory: URL, maxPending: Int = 300) {
        self.directory = directory
        self.maxPending = maxPending
    }

    /// `nil` when the App Group capability is missing.
    static func appGroup() -> LiveChannel? {
        AppGroup.containerURL.map { LiveChannel(directory: $0.appending(path: "Live", directoryHint: .isDirectory)) }
    }

    private var inbox: URL { directory.appending(path: "Inbox", directoryHint: .isDirectory) }
    private var controlURL: URL { directory.appending(path: "control.json") }
    private var statusURL: URL { directory.appending(path: "status.json") }

    // MARK: Batches

    func send(_ batch: LiveBatch) throws {
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(batch)
        try data.write(to: inbox.appending(path: fileName(for: batch)), options: Self.writeOptions)
        trim()
    }

    /// Reads and removes everything pending, oldest first.
    func drain() -> [LiveBatch] {
        pendingFiles().compactMap { file in
            defer { try? FileManager.default.removeItem(at: file) }
            guard let data = try? Data(contentsOf: file) else { return nil }
            return try? JSONDecoder().decode(LiveBatch.self, from: data)
        }
    }

    func removeAllBatches() {
        for file in pendingFiles() { try? FileManager.default.removeItem(at: file) }
    }

    /// Names sort by time, then by order inside the session.
    private func fileName(for batch: LiveBatch) -> String {
        let milliseconds = Int(batch.date.timeIntervalSince1970 * 1000)
        return String(format: "%015d-%08d.json", milliseconds, batch.sequence)
    }

    private func pendingFiles() -> [URL] {
        let files = try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)
        return (files ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// The app may stay closed for a whole session, so drop the oldest.
    private func trim() {
        let files = pendingFiles()
        for file in files.prefix(max(0, files.count - maxPending)) { try? FileManager.default.removeItem(at: file) }
    }

    // MARK: Status and control

    func write(_ status: LiveStatus) throws { try write(status, to: statusURL) }

    func status() -> LiveStatus? { read(LiveStatus.self, from: statusURL) }

    func write(_ control: LiveControl) throws { try write(control, to: controlURL) }

    func control() -> LiveControl { read(LiveControl.self, from: controlURL) ?? LiveControl() }

    private func write(_ value: some Encodable, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: Self.writeOptions)
    }

    private func read<Value: Decodable>(_ type: Value.Type, from url: URL) -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Writable while the device is locked, unreadable to others once closed.
    private static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtectionUnlessOpen]
}
