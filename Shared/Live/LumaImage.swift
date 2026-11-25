import Accelerate
import CoreGraphics
import Foundation

/// Small 8-bit grayscale copy of a frame. Holding this instead of the
/// full-size pixel buffer is what keeps the extension's memory low.
nonisolated struct LumaImage: Sendable {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    /// Scales a grayscale plane down so its longest side is at most `maxDimension`.
    static func downscaled(
        from base: UnsafeRawPointer, width: Int, height: Int, bytesPerRow: Int, maxDimension: Int
    ) -> LumaImage? {
        guard width > 0, height > 0 else { return nil }
        let scale = min(1, Double(maxDimension) / Double(max(width, height)))
        return scaled(
            from: base, width: width, height: height, bytesPerRow: bytesPerRow,
            toWidth: max(1, Int(Double(width) * scale)), toHeight: max(1, Int(Double(height) * scale))
        )
    }

    /// - Parameter region: Normalized, top-left origin.
    func cropped(to region: CGRect, maxDimension: Int) -> LumaImage? {
        pixels.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return nil }
            return Self.cropped(
                from: base, width: width, height: height, bytesPerRow: width,
                region: region, maxDimension: maxDimension
            )
        }
    }

    static func cropped(
        from base: UnsafeRawPointer, width: Int, height: Int, bytesPerRow: Int,
        region: CGRect, maxDimension: Int
    ) -> LumaImage? {
        let crop = pixelRect(region, width: width, height: height)
        guard !crop.isNull, crop.width >= 1, crop.height >= 1 else { return nil }
        return downscaled(
            from: base + Int(crop.minY) * bytesPerRow + Int(crop.minX),
            width: Int(crop.width), height: Int(crop.height), bytesPerRow: bytesPerRow, maxDimension: maxDimension
        )
    }

    static func pixelRect(_ region: CGRect, width: Int, height: Int) -> CGRect {
        let full = CGRect(x: 0, y: 0, width: width, height: height)
        return CGRect(
            x: region.minX * full.width, y: region.minY * full.height,
            width: region.width * full.width, height: region.height * full.height
        ).integral.intersection(full)
    }

    func scaled(toWidth: Int, toHeight: Int) -> LumaImage? {
        pixels.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return nil }
            return Self.scaled(
                from: base, width: width, height: height, bytesPerRow: width, toWidth: toWidth, toHeight: toHeight
            )
        }
    }

    private static func scaled(
        from base: UnsafeRawPointer, width: Int, height: Int, bytesPerRow: Int, toWidth: Int, toHeight: Int
    ) -> LumaImage? {
        var source = vImage_Buffer(
            data: UnsafeMutableRawPointer(mutating: base),
            height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow
        )
        var pixels = [UInt8](repeating: 0, count: toWidth * toHeight)
        let status = pixels.withUnsafeMutableBytes { output in
            var destination = vImage_Buffer(
                data: output.baseAddress,
                height: vImagePixelCount(toHeight), width: vImagePixelCount(toWidth), rowBytes: toWidth
            )
            return vImageScale_Planar8(&source, &destination, nil, vImage_Flags(kvImageNoFlags))
        }
        return status == kvImageNoError ? LumaImage(width: toWidth, height: toHeight, pixels: pixels) : nil
    }

    func makeCGImage() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [], provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}
