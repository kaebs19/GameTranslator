import CoreGraphics
import Foundation
import ImageIO

nonisolated enum ImageLoader {
    /// Decodes upright and caps the size so huge photos stay cheap to process.
    @concurrent
    static func decode(_ data: Data, maxDimension: Int = 4096) async throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw AppError.unreadableImage
        }
        return image
    }
}
