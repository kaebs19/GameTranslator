import UIKit

/// Background color of a region, taken as the median of its border pixels.
nonisolated struct RegionColor: Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    static let black = RegionColor(red: 0, green: 0, blue: 0)

    var uiColor: UIColor {
        UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }

    var readableTextColor: UIColor { isLight ? .black : .white }

    /// W3C relative luminance; 0.179 is where black and white contrast equally.
    var isLight: Bool {
        func linear(_ value: UInt8) -> Double {
            let v = Double(value) / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue) > 0.179
    }

    static func sample(_ image: CGImage, in rect: CGRect) -> RegionColor {
        guard let crop = image.cropping(to: rect) else { return .black }
        // Small enough to be cheap, large enough to keep a distinct border.
        let width = min(crop.width, 96), height = min(crop.height, 48)
        guard width > 0, height > 0 else { return .black }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? borderMedian(pixels, width: width, height: height) : .black
    }

    private static func borderMedian(_ pixels: [UInt8], width: Int, height: Int) -> RegionColor {
        var channels: [[UInt8]] = [[], [], []]
        for y in 0..<height {
            for x in 0..<width where y == 0 || y == height - 1 || x == 0 || x == width - 1 {
                let offset = (y * width + x) * 4
                for channel in 0..<3 { channels[channel].append(pixels[offset + channel]) }
            }
        }
        let medians = channels.map { $0.sorted()[$0.count / 2] }
        return RegionColor(red: medians[0], green: medians[1], blue: medians[2])
    }
}
