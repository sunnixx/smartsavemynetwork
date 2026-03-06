import Photos
import UIKit

struct PhotoSyncService {
    private static let albumName = "SmartSave"

    // MARK: - Permissions

    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    // MARK: - Album Management

    static func findOrCreateAlbum() throws -> PHAssetCollection {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let existing = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let album = existing.firstObject {
            return album
        }

        var albumPlaceholder: PHObjectPlaceholder?
        try PHPhotoLibrary.shared().performChangesAndWait {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            albumPlaceholder = request.placeholderForCreatedAssetCollection
        }

        guard let placeholder = albumPlaceholder,
              let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil).firstObject else {
            throw SyncError.albumCreationFailed
        }

        return album
    }

    // MARK: - Save Image

    static func saveImage(_ image: UIImage, contactName: String) throws -> String {
        let album = try findOrCreateAlbum()
        var localIdentifier = ""

        try PHPhotoLibrary.shared().performChangesAndWait {
            let creationRequest = PHAssetCreationRequest.creationRequestForAsset(from: image)
            creationRequest.creationDate = Date()

            guard let placeholder = creationRequest.placeholderForCreatedAsset else { return }
            localIdentifier = placeholder.localIdentifier

            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else { return }
            albumChangeRequest.addAssets([placeholder] as NSFastEnumeration)
        }

        return localIdentifier
    }

    // MARK: - Fetch Image by Local Identifier

    static func fetchImage(localIdentifier: String) -> UIImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = true

        var result: UIImage?
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            result = image
        }
        return result
    }

    // MARK: - Fetch All Images from Album

    static func fetchAllAlbumAssets() -> [(localIdentifier: String, image: UIImage)] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        guard let album = albums.firstObject else { return [] }

        let assetFetchOptions = PHFetchOptions()
        assetFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(in: album, options: assetFetchOptions)

        var results: [(String, UIImage)] = []
        let imageOptions = PHImageRequestOptions()
        imageOptions.deliveryMode = .highQualityFormat
        imageOptions.isSynchronous = true

        assets.enumerateObjects { asset, _, _ in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: imageOptions
            ) { image, _ in
                if let image = image {
                    results.append((asset.localIdentifier, image))
                }
            }
        }

        return results
    }

    enum SyncError: Error {
        case albumCreationFailed
    }
}
