import CoreGraphics
import Foundation

/// Lines that form one sentence or paragraph, to be translated together.
nonisolated struct TextBlock: Identifiable, Hashable, Sendable {
    let lines: [RecognizedLine]
    let text: String

    var id: UUID { lines[0].id }

    var boundingBox: CGRect {
        lines.dropFirst().reduce(lines[0].boundingBox) { $0.union($1.boundingBox) }
    }

    /// Tallest line, normalized to the image height.
    var lineHeight: CGFloat { lines.map(\.boundingBox.height).max() ?? 0 }
}

/// Joins a wrapped sentence back together.
///
/// Deliberately careful: menus are also stacked lines, and joining "Continue" with "Options"
/// is worse than translating one sentence in two halves. So being close is not enough,
/// the text itself must look unfinished.
nonisolated enum LineMerger {
    /// - Parameters:
    ///   - lines: In reading order.
    ///   - aspectRatio: Image width over height. Boxes are normalized per axis, so without it
    ///     horizontal and vertical distances cannot be compared.
    static func blocks(from lines: [RecognizedLine], aspectRatio: CGFloat) -> [TextBlock] {
        var groups: [[RecognizedLine]] = []
        for line in lines {
            // Columns interleave in reading order, so look at every open group, newest first.
            let match = groups.indices.reversed().first { continues(groups[$0], with: line, aspectRatio) }
            if let match {
                groups[match].append(line)
            } else {
                groups.append([line])
            }
        }
        return groups.map { TextBlock(lines: $0, text: joined($0.map(\.text))) }
    }

    private static func continues(_ group: [RecognizedLine], with next: RecognizedLine, _ aspect: CGFloat) -> Bool {
        guard let last = group.last else { return false }
        return isBelow(last.boundingBox, next.boundingBox)
            && isAligned(last.boundingBox, next.boundingBox, aspect)
            && readsOn(from: last.text, to: next.text)
    }

    // MARK: Layout

    private static func isBelow(_ a: CGRect, _ b: CGRect) -> Bool {
        guard a.height > 0, b.height > 0 else { return false }
        let height = min(a.height, b.height)
        // Lines without tall letters have shorter boxes at the same font size.
        guard max(a.height, b.height) / height <= 1.6 else { return false }
        let gap = b.minY - a.maxY
        // A tilted camera makes the boxes taller, so they overlap more than the text does.
        return gap <= height && gap >= -height * 0.6
    }

    private static func isAligned(_ a: CGRect, _ b: CGRect, _ aspect: CGFloat) -> Bool {
        let tolerance = max(a.height, b.height) * 1.5
        let left = abs(a.minX - b.minX) * aspect
        let right = abs(a.maxX - b.maxX) * aspect
        let center = abs(a.midX - b.midX) * aspect
        return min(left, right, center) <= tolerance
    }

    // MARK: Text

    private static let openEndings: Set<String> = [
        "a", "an", "the", "to", "of", "and", "or", "but", "in", "on", "at", "for", "with", "from", "by", "as",
        "is", "are", "was", "be", "your", "my", "his", "her", "their", "our", "this", "that", "if", "before", "after",
        "into", "onto", "about", "than", "so", "when", "where", "while", "because", "until", "through", "who",
        "which", "will", "would", "can", "could", "should", "must", "have", "has", "had", "were", "been", "not",
        "we", "i", "they", "these", "those", "its", "every", "each", "some", "any", "no", "very", "more", "most"
    ]

    static func readsOn(from first: String, to second: String) -> Bool {
        guard let end = first.last, let start = second.first(where: { $0.isLetter || $0.isNumber }) else { return false }
        if ".!?:;…。！？".contains(end) { return false }
        if isUnspaced(end), isUnspaced(start) { return first.count >= 8 }
        if ",-،".contains(end) { return true }
        // A single short word above is more likely a label or a menu entry.
        let words = first.split(separator: " ")
        guard words.count >= 2, let lastWord = words.last else { return false }
        return start.isLowercase || openEndings.contains(lastWord.lowercased())
    }

    /// Chinese and Japanese put no space between words.
    private static func isUnspaced(_ character: Character) -> Bool {
        character.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
    }

    static func joined(_ texts: [String]) -> String {
        texts.dropFirst().reduce(texts.first ?? "") { result, next in
            guard let end = result.last, let start = next.first else { return result + next }
            if end == "-", start.isLowercase { return result.dropLast() + next }
            return isUnspaced(end) && isUnspaced(start) ? result + next : result + " " + next
        }
    }
}
