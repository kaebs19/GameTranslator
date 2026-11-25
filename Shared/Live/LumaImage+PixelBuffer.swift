import Accelerate
import CoreVideo

nonisolated extension LumaImage {
    /// Supports every format screen capture delivers on iOS; `nil` for anything else.
    static func downscaled(from buffer: CVPixelBuffer, maxDimension: Int) -> LumaImage? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        switch CVPixelBufferGetPixelFormatType(buffer) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return fromLumaPlane(buffer, maxDimension: maxDimension)
        case kCVPixelFormatType_32BGRA:
            return fromBGRA(buffer, maxDimension: maxDimension)
        case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
            return fromTenBitLumaPlane(buffer, maxDimension: maxDimension)
        default:
            return nil
        }
    }

    /// Only part of an 8-bit bi-planar frame.
    /// - Parameter region: Normalized, top-left origin, in the buffer's own orientation.
    static func downscaled(from buffer: CVPixelBuffer, region: CGRect, maxDimension: Int) -> LumaImage? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard CVPixelBufferGetPlaneCount(buffer) == 2, let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else {
            return nil
        }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0), height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        return cropped(
            from: base, width: width, height: height, bytesPerRow: bytesPerRow,
            region: region, maxDimension: maxDimension
        )
    }

    /// Plane 0 already is a grayscale image.
    private static func fromLumaPlane(_ buffer: CVPixelBuffer, maxDimension: Int) -> LumaImage? {
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return nil }
        return downscaled(
            from: base,
            width: CVPixelBufferGetWidthOfPlane(buffer, 0), height: CVPixelBufferGetHeightOfPlane(buffer, 0),
            bytesPerRow: CVPixelBufferGetBytesPerRowOfPlane(buffer, 0), maxDimension: maxDimension
        )
    }

    private static func fromTenBitLumaPlane(_ buffer: CVPixelBuffer, maxDimension: Int) -> LumaImage? {
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return nil }
        var source = vImage_Buffer(
            data: base, height: vImagePixelCount(CVPixelBufferGetHeightOfPlane(buffer, 0)),
            width: vImagePixelCount(CVPixelBufferGetWidthOfPlane(buffer, 0)),
            rowBytes: CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        )
        let (width, height) = fittedSize(source, maxDimension)
        var small = [UInt16](repeating: 0, count: width * height)
        let status = small.withUnsafeMutableBytes { bytes in
            var output = vImage_Buffer(
                data: bytes.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width),
                rowBytes: width * 2
            )
            return vImageScale_Planar16U(&source, &output, nil, vImage_Flags(kvImageNoFlags))
        }
        guard status == kvImageNoError else { return nil }
        // The ten bits sit at the top of each 16-bit value.
        return LumaImage(width: width, height: height, pixels: small.map { UInt8($0 >> 8) })
    }

    private static func fromBGRA(_ buffer: CVPixelBuffer, maxDimension: Int) -> LumaImage? {
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        var source = vImage_Buffer(
            data: base, height: vImagePixelCount(CVPixelBufferGetHeight(buffer)),
            width: vImagePixelCount(CVPixelBufferGetWidth(buffer)), rowBytes: CVPixelBufferGetBytesPerRow(buffer)
        )
        let (width, height) = fittedSize(source, maxDimension)
        var color = [UInt8](repeating: 0, count: width * height * 4)
        var gray = [UInt8](repeating: 0, count: width * height)
        let status = color.withUnsafeMutableBytes { colorBytes in
            gray.withUnsafeMutableBytes { grayBytes in
                var small = vImage_Buffer(
                    data: colorBytes.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width),
                    rowBytes: width * 4
                )
                var output = vImage_Buffer(
                    data: grayBytes.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width),
                    rowBytes: width
                )
                let scaled = vImageScale_ARGB8888(&source, &small, nil, vImage_Flags(kvImageNoFlags))
                guard scaled == kvImageNoError else { return scaled }
                // Rec. 601 weights in B, G, R, A order, over 256.
                let weights: [Int16] = [29, 150, 77, 0]
                return vImageMatrixMultiply_ARGB8888ToPlanar8(
                    &small, &output, weights, 256, nil, 0, vImage_Flags(kvImageNoFlags)
                )
            }
        }
        return status == kvImageNoError ? LumaImage(width: width, height: height, pixels: gray) : nil
    }

    private static func fittedSize(_ buffer: vImage_Buffer, _ maxDimension: Int) -> (Int, Int) {
        let width = Int(buffer.width), height = Int(buffer.height)
        let scale = min(1, Double(maxDimension) / Double(max(width, height, 1)))
        return (max(1, Int(Double(width) * scale)), max(1, Int(Double(height) * scale)))
    }
}
