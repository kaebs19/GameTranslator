import Testing
import UIKit
@testable import GameTranslator

enum TestImage {
    static func make(lines: [String], size: CGSize = CGSize(width: 1000, height: 500)) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.1, green: 0.15, blue: 0.3, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(
                    at: CGPoint(x: 100, y: 100 + 200 * index),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 64), .foregroundColor: UIColor.white]
                )
            }
        }.cgImage
    }

    static func png(lines: [String]) throws -> Data {
        try #require(make(lines: lines).flatMap { UIImage(cgImage: $0).pngData() })
    }

    /// Grayscale copy, like the frames the extension works with.
    static func luma(lines: [String]) throws -> LumaImage {
        let image = try #require(make(lines: lines))
        var pixels = [UInt8](repeating: 0, count: image.width * image.height)
        pixels.withUnsafeMutableBytes { buffer in
            CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return LumaImage(width: image.width, height: image.height, pixels: pixels)
    }
}
