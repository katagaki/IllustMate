//
//  PhotosManager.swift
//  PicMate
//
//  Created on 2026/02/26.
//

import Foundation
import Photos

@MainActor
@Observable
class PhotosManager {

    var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
            }
        }
    }

    // MARK: - Fetch Top-Level Collections

    func fetchTopLevelCollections() -> [PHCollectionItem] {
        var collected: [PHCollectionItem] = []
        let result = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        result.enumerateObjects { collection, _, _ in
            if let album = collection as? PHAssetCollection {
                collected.append(.album(album))
            } else if let folder = collection as? PHCollectionList {
                collected.append(.folder(folder))
            }
        }
        return collected.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    // MARK: - Fetch Collections in Folder

    func fetchCollections(in folder: PHCollectionList) -> [PHCollectionItem] {
        var collected: [PHCollectionItem] = []
        let result = PHCollection.fetchCollections(in: folder, options: nil)
        result.enumerateObjects { collection, _, _ in
            if let album = collection as? PHAssetCollection {
                collected.append(.album(album))
            } else if let subfolder = collection as? PHCollectionList {
                collected.append(.folder(subfolder))
            }
        }
        return collected.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    // MARK: - Fetch Assets in Album

    func fetchAssets(in collection: PHAssetCollection) -> PHFetchResult<PHAsset> {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(in: collection, options: fetchOptions)
    }

    func imageCount(in collection: PHAssetCollection) -> Int {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        return PHAsset.fetchAssets(in: collection, options: fetchOptions).count
    }

    func firstAsset(in collection: PHAssetCollection) -> PHAsset? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(in: collection, options: fetchOptions).firstObject
    }

    // MARK: - Fetch Assets Not in Any Album

    func fetchAssetsNotInAnyAlbum() async -> [PHAsset] {
        await Task.detached(priority: .userInitiated) {
            // Fetch all image assets
            let allOptions = PHFetchOptions()
            allOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            allOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let allAssets = PHAsset.fetchAssets(with: allOptions)

            // Collect identifiers of assets that belong to any user album
            var albumedIdentifiers: Set<String> = []
            albumedIdentifiers.reserveCapacity(allAssets.count)
            let albums = PHAssetCollection.fetchAssetCollections(
                with: .album, subtype: .any, options: nil
            )
            albums.enumerateObjects { collection, _, _ in
                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(
                    format: "mediaType = %d", PHAssetMediaType.image.rawValue
                )
                let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                assets.enumerateObjects { asset, _, _ in
                    albumedIdentifiers.insert(asset.localIdentifier)
                }
            }

            // Return assets not in any album
            var result: [PHAsset] = []
            result.reserveCapacity(max(0, allAssets.count - albumedIdentifiers.count))
            allAssets.enumerateObjects { asset, _, _ in
                if !albumedIdentifiers.contains(asset.localIdentifier) {
                    result.append(asset)
                }
            }
            return result
        }.value
    }

    // MARK: - Nested Albums (Experimental)

    /// In nested albums mode, within a folder:
    /// - If an album named "▶︎ <FolderName>" exists, its photos become the folder's own pics
    /// - The remaining albums become nested sub-albums
    /// Returns (ownPicsAlbum, childAlbums, childFolders)
    func resolveNestedAlbums(
        in folder: PHCollectionList
    ) -> (ownPicsCollection: PHAssetCollection?, albums: [PHAssetCollection], folders: [PHCollectionList]) {
        let folderName = folder.localizedTitle ?? ""
        let markerName = "▶︎ \(folderName)"
        var ownPicsCollection: PHAssetCollection?
        var albums: [PHAssetCollection] = []
        var folders: [PHCollectionList] = []

        let result = PHCollection.fetchCollections(in: folder, options: nil)
        result.enumerateObjects { collection, _, _ in
            if let album = collection as? PHAssetCollection {
                if album.localizedTitle == markerName {
                    ownPicsCollection = album
                } else {
                    albums.append(album)
                }
            } else if let subfolder = collection as? PHCollectionList {
                folders.append(subfolder)
            }
        }

        albums.sort {
            ($0.localizedTitle ?? "").localizedCaseInsensitiveCompare($1.localizedTitle ?? "") == .orderedAscending
        }
        folders.sort {
            ($0.localizedTitle ?? "").localizedCaseInsensitiveCompare($1.localizedTitle ?? "") == .orderedAscending
        }

        return (ownPicsCollection, albums, folders)
    }
}
