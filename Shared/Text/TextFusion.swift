import Foundation

/// Combines several imperfect readings of the same text into a better one.
///
/// Each camera frame misreads different letters, especially in long sentences. The readings are
/// aligned word by word and each word is decided by vote, so one bad frame cannot spoil the result.
nonisolated enum TextFusion {
    /// Share of words two readings must have in common to be the same text.
    static let minimumSimilarity = 0.5

    /// - Parameter readings: Readings of one text. On a tie the earlier one wins, so pass
    ///   the preferred reading first.
    static func fused(_ readings: [String]) -> String {
        let all = readings.map(Words.init).filter { !$0.keys.isEmpty }
        guard all.count > 2 else { return readings.first ?? "" }
        let costs = all.map { cost(of: $0, in: all) }
        let center = costs.indices.min { costs[$0] < costs[$1] } ?? 0
        let backbone = all[center]
        var slots = backbone.keys.indices.map { [Vote(key: backbone.keys[$0], text: backbone.texts[$0])] }
        var insertions: [Int: [String: (count: Int, text: String)]] = [:]
        for (index, reading) in all.enumerated() where index != center {
            for step in align(reading, to: backbone) {
                switch step {
                case .match(let source, let target):
                    slots[target].append(Vote(key: reading.keys[source], text: reading.texts[source]))
                case .missing(let target):
                    slots[target].append(Vote(key: nil, text: nil))
                case .extra(let after, let sources):
                    let key = sources.map { reading.keys[$0] }.joined(separator: " ")
                    let text = sources.map { reading.texts[$0] }.joined(separator: " ")
                    insertions[after, default: [:]][key, default: (0, text)].count += 1
                }
            }
        }
        // Every reading without the backbone's own votes for "nothing here".
        let majority = all.count / 2 + 1
        var words: [String] = []
        for target in -1..<slots.count {
            if target >= 0, let text = winner(of: slots[target], majority: majority) { words.append(text) }
            if let best = insertions[target]?.values.max(by: { $0.count < $1.count }), best.count >= majority {
                words.append(best.text)
            }
        }
        return words.joined(separator: " ")
    }

    /// 0 for nothing in common, 1 for the same words.
    static func similarity(_ a: String, _ b: String) -> Double {
        let (x, y) = (Words(a).keys, Words(b).keys)
        guard !x.isEmpty || !y.isEmpty else { return 1 }
        return 1 - Double(distance(x, y)) / Double(max(x.count, y.count))
    }

    // MARK: Votes

    private struct Vote {
        /// `nil` when the reading has no word here.
        let key: String?
        let text: String?
    }

    /// The backbone's vote comes first and wins ties.
    private static func winner(of votes: [Vote], majority: Int) -> String? {
        var counts: [String?: Int] = [:]
        for vote in votes { counts[vote.key, default: 0] += 1 }
        // On a tie the backbone's word stays.
        let best = votes.map(\.key).reduce(votes[0].key) { counts[$1]! > counts[$0]! ? $1 : $0 }
        // A word only half the readings have is still kept: dropping text is worse than a stray word.
        guard let best else { return nil }
        _ = majority
        // The spelling most readings agree on, such as "is" over "Is".
        let forms = votes.filter { $0.key == best }.compactMap(\.text)
        return forms.reduce(forms.first) { best, form in
            forms.count { $0 == form } > forms.count { $0 == best } ? form : best
        }
    }

    private static func cost(of reading: Words, in all: [Words]) -> Int {
        all.reduce(0) { $0 + distance(reading.keys, $1.keys) }
    }

    // MARK: Alignment

    private struct Words {
        /// For comparing: case, accents and punctuation removed.
        let keys: [String]
        /// As read, for showing.
        let texts: [String]

        init(_ text: String) {
            let pairs = text.split(separator: " ").compactMap { token -> (String, String)? in
                let key = TextNormalizer.comparisonKey(String(token)).replacingOccurrences(of: " ", with: "")
                return key.isEmpty ? nil : (key, String(token))
            }
            keys = pairs.map(\.0)
            texts = pairs.map(\.1)
        }
    }

    private enum Step {
        case match(source: Int, target: Int)
        case missing(target: Int)
        /// Words of the reading that the backbone does not have, after backbone word `after`.
        case extra(after: Int, sources: [Int])
    }

    private static func align(_ reading: Words, to backbone: Words) -> [Step] {
        let (a, b) = (reading.keys, backbone.keys)
        let table = distanceTable(a, b)
        var steps: [Step] = []
        var pending: [Int] = []
        var (i, j) = (a.count, b.count)
        func flush() {
            if !pending.isEmpty { steps.append(.extra(after: j - 1, sources: pending.reversed())) }
            pending = []
        }
        while i > 0 || j > 0 {
            if i > 0, j > 0, table[i][j] == table[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1) {
                flush()
                steps.append(.match(source: i - 1, target: j - 1))
                (i, j) = (i - 1, j - 1)
            } else if i > 0, table[i][j] == table[i - 1][j] + 1 {
                pending.append(i - 1)
                i -= 1
            } else {
                flush()
                steps.append(.missing(target: j - 1))
                j -= 1
            }
        }
        flush()
        return steps
    }

    private static func distance(_ a: [String], _ b: [String]) -> Int {
        distanceTable(a, b)[a.count][b.count]
    }

    private static func distanceTable(_ a: [String], _ b: [String]) -> [[Int]] {
        var table = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { table[i][0] = i }
        for j in 0...b.count { table[0][j] = j }
        for i in stride(from: 1, through: a.count, by: 1) {
            for j in stride(from: 1, through: b.count, by: 1) {
                table[i][j] = min(
                    table[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1), table[i - 1][j] + 1, table[i][j - 1] + 1
                )
            }
        }
        return table
    }
}
