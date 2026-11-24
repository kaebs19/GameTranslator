import CoreGraphics
import Foundation
import Vision

/// On-device text recognition built on Vision.
nonisolated struct OCRService: Sendable {
    enum Mode: Sendable {
        /// Low memory and latency. Used for live frames.
        case fast
        /// Best quality. Used for single screenshots.
        case accurate

        var recognitionLevel: VNRequestTextRecognitionLevel {
            switch self {
            case .fast: .fast
            case .accurate: .accurate
            }
        }
    }

    var mode: Mode = .accurate
    /// Vision language codes, for example `en-US`.
    var languages: [String] = ["en-US"]
    var minimumConfidence: Float = 0.3

    /// Runs off the main actor and returns lines in reading order.
    @concurrent
    func recognizeText(in image: CGImage) async throws -> [RecognizedLine] {
        try Task.checkCancellation()
        let request = makeRequest()
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        try Task.checkCancellation()
        let lines = (request.results ?? []).compactMap(line(from:))
        return Self.sortedInReadingOrder(lines)
    }

    private func makeRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = mode.recognitionLevel
        request.usesLanguageCorrection = mode == .accurate
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let usable = languages.filter(supported.contains)
        if !usable.isEmpty { request.recognitionLanguages = usable }
        return request
    }

    private func line(from observation: VNRecognizedTextObservation) -> RecognizedLine? {
        guard let candidate = observation.topCandidates(1).first,
              candidate.confidence >= minimumConfidence else { return nil }
        let text = TextNormalizer.collapsingWhitespace(candidate.string)
        guard !text.isEmpty else { return nil }
        return RecognizedLine(
            text: text,
            boundingBox: Self.topLeftBox(fromVision: observation.boundingBox),
            confidence: candidate.confidence
        )
    }

    /// Vision uses a bottom-left origin; UIKit uses top-left.
    static func topLeftBox(fromVision box: CGRect) -> CGRect {
        CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
    }

    /// Top to bottom; boxes whose centers share a row are ordered left to right.
    static func sortedInReadingOrder(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        var rows: [[RecognizedLine]] = []
        for line in lines.sorted(by: { $0.boundingBox.midY < $1.boundingBox.midY }) {
            if let anchor = rows.last?.first,
               abs(line.boundingBox.midY - anchor.boundingBox.midY) < min(line.boundingBox.height, anchor.boundingBox.height) / 2 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows.flatMap { $0.sorted { $0.boundingBox.minX < $1.boundingBox.minX } }
    }
}
