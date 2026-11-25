/// Coarse brightness grid used to tell whether a frame changed.
nonisolated struct FrameFingerprint: Equatable, Sendable {
    static let side = 64
    /// Brightness steps a cell must move before it counts, to ignore video noise.
    static let cellTolerance = 8
    /// A short new word touches only a few cells out of 4096.
    static let minimumChangedCells = 4

    private let cells: [UInt8]

    init?(_ image: LumaImage) {
        guard let grid = image.scaled(toWidth: Self.side, toHeight: Self.side) else { return nil }
        cells = grid.pixels
    }

    func isSimilar(to other: FrameFingerprint) -> Bool {
        var changed = 0
        for (a, b) in zip(cells, other.cells) where abs(Int(a) - Int(b)) > Self.cellTolerance {
            changed += 1
            if changed >= Self.minimumChangedCells { return false }
        }
        return true
    }
}
