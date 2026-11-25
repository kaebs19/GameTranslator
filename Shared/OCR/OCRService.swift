import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Finds lines of text in an image.
nonisolated protocol TextRecognizing: Sendable {
    /// Languages this recognizer can read.
    var readableLanguages: Set<AppLanguage> { get }
    func recognizeText(in image: CGImage, language: AppLanguage) async throws -> [RecognizedLine]
}

/// On-device text recognition built on Vision.
nonisolated struct OCRService: TextRecognizing {
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
    var minimumConfidence: Float = 0.3

    var readableLanguages: Set<AppLanguage> {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = mode.recognitionLevel
        return Set(Self.visionCodes(of: request).map(AppLanguage.init(code:)))
    }

    /// Runs off the main actor and returns lines in reading order.
    @concurrent
    func recognizeText(in image: CGImage, language: AppLanguage) async throws -> [RecognizedLine] {
        try Task.checkCancellation()
        let lines = try recognize(image, orientation: .up, language: language)
        try Task.checkCancellation()
        return lines
    }

    /// Blocking version, for callers that already own a background queue.
    func recognize(
        _ image: CGImage, orientation: CGImagePropertyOrientation, language: AppLanguage
    ) throws -> [RecognizedLine] {
        let request = makeRequest(language: language)
        try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
        return Self.sortedInReadingOrder((request.results ?? []).compactMap(line(from:)))
    }

    private func makeRequest(language: AppLanguage) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = mode.recognitionLevel
        request.usesLanguageCorrection = mode == .accurate
        let codes = Self.visionCodes(of: request).filter { AppLanguage(code: $0) == language }
        if !codes.isEmpty { request.recognitionLanguages = codes }
        return request
    }

    /// Vision names languages by region, for example `en-US`.
    private static func visionCodes(of request: VNRecognizeTextRequest) -> [String] {
        (try? request.supportedRecognitionLanguages()) ?? []
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
