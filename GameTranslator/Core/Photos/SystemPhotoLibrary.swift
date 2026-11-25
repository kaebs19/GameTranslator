import Foundation
import Photos

nonisolated protocol PhotoLibraryProviding: Sendable {
    func latestScreenshotData() async throws -> Data
    func save(_ imageData: Data) async throws
}

nonisolated struct SystemPhotoLibrary: PhotoLibraryProviding {
    func latestScreenshotData() async throws -> Data {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { throw AppError.photoAccessDenied }
        guard let asset = latestScreenshotAsset() else {
            throw status == .limited ? AppError.photoAccessLimited : AppError.noScreenshot
        }
        return try await data(for: asset)
    }

    func save(_ imageData: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw AppError.photoAccessDenied }
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData, options: nil)
        }
    }

    private func latestScreenshotAsset() -> PHAsset? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        return PHAsset.fetchAssets(with: .image, options: options).firstObject
    }

    private func data(for asset: PHAsset) async throws -> Data {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.version = .current
        options.isNetworkAccessAllowed = false
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { @Sendable data, _, _, _ in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: AppError.unreadableImage)
                }
            }
        }
    }
}
