//
//  PhotosLibraryManager.swift
//  IllustMate
//
//  Created for migration to Photos library
//

import Foundation
import Photos
import UIKit

@MainActor
class PhotosLibraryManager: ObservableObject {
    
    static let shared = PhotosLibraryManager()
    
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        return status
    }
    
    // MARK: - Album (Collection) Operations
    
    /// Fetches all user-created albums (PHAssetCollections)
    func fetchUserAlbums(in parentCollection: PHCollectionList? = nil) -> [PHAssetCollection] {
        var collections: [PHAssetCollection] = []
        
        if let parentCollection = parentCollection {
            // Fetch collections within a folder
            let fetchResult = PHAssetCollection.fetchCollections(
                in: parentCollection,
                options: nil
            )
            fetchResult.enumerateObjects { collection, _, _ in
                collections.append(collection)
            }
        } else {
            // Fetch top-level user albums
            let fetchOptions = PHFetchOptions()
            let userAlbums = PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .albumRegular,
                options: fetchOptions
            )
            userAlbums.enumerateObjects { collection, _, _ in
                collections.append(collection)
            }
        }
        
        return collections
    }
    
    /// Fetches all user-created folders (PHCollectionLists)
    func fetchUserFolders(in parentFolder: PHCollectionList? = nil) -> [PHCollectionList] {
        var folders: [PHCollectionList] = []
        
        let fetchOptions = PHFetchOptions()
        let collectionLists: PHFetchResult<PHCollectionList>
        
        if let parentFolder = parentFolder {
            collectionLists = PHCollectionList.fetchCollections(
                in: parentFolder,
                options: fetchOptions
            )
        } else {
            collectionLists = PHCollectionList.fetchTopLevelUserCollections(with: fetchOptions)
        }
        
        collectionLists.enumerateObjects { collectionList, _, _ in
            if collectionList.collectionListType == .folder {
                folders.append(collectionList)
            }
        }
        
        return folders
    }
    
    /// Fetches photos (PHAssets) from a collection
    func fetchAssets(in collection: PHAssetCollection, sortOrder: SortOrder = .reverse) -> [PHAsset] {
        var assets: [PHAsset] = []
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: sortOrder == .forward)]
        
        let fetchResult = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        fetchResult.enumerateObjects { asset, _, _ in
            if asset.mediaType == .image {
                assets.append(asset)
            }
        }
        
        return assets
    }
    
    /// Count of albums in a folder
    func albumCount(in folder: PHCollectionList) -> Int {
        let collections = PHAssetCollection.fetchCollections(in: folder, options: nil)
        return collections.count
    }
    
    /// Count of photos in a collection
    func assetCount(in collection: PHAssetCollection) -> Int {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let fetchResult = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        return fetchResult.count
    }
    
    /// Detects if an album with the same name as the folder exists within the folder
    /// This implements the special case logic: if found, photos in that album are considered
    /// to be in the folder directly rather than in a nested album
    func detectSameNameAlbum(in folder: PHCollectionList) -> PHAssetCollection? {
        let folderName = folder.localizedTitle ?? ""
        let albums = fetchUserAlbums(in: folder)
        
        return albums.first { album in
            album.localizedTitle == folderName
        }
    }
    
    // MARK: - Asset Operations
    
    /// Load image data for an asset
    func loadImage(for asset: PHAsset, targetSize: CGSize = PHImageManagerMaximumSize, 
                   contentMode: PHImageContentMode = .aspectFit) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    /// Load thumbnail for an asset
    func loadThumbnail(for asset: PHAsset) async -> UIImage? {
        let thumbnailSize = CGSize(width: 120, height: 120)
        return await loadImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill)
    }
    
    /// Load full resolution image data for an asset
    func loadImageData(for asset: PHAsset) async -> Data? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
    
    // MARK: - Create Operations
    
    /// Creates a new album
    func createAlbum(named name: String) async throws -> PHAssetCollection {
        return try await withCheckedThrowingContinuation { continuation in
            var albumPlaceholder: PHObjectPlaceholder?
            
            PHPhotoLibrary.shared().performChanges({
                let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                albumPlaceholder = createRequest.placeholderForCreatedAssetCollection
            }) { success, error in
                if success, 
                   let placeholder = albumPlaceholder,
                   let album = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: [placeholder.localIdentifier],
                    options: nil
                   ).firstObject {
                    continuation.resume(returning: album)
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "PhotosLibraryManager", code: -1))
                }
            }
        }
    }
    
    /// Adds an image to an album
    func addImage(_ image: UIImage, to album: PHAssetCollection) async throws -> PHAsset {
        return try await withCheckedThrowingContinuation { continuation in
            var assetPlaceholder: PHObjectPlaceholder?
            
            PHPhotoLibrary.shared().performChanges({
                let createRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                assetPlaceholder = createRequest.placeholderForCreatedAsset
                
                if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                   let placeholder = createRequest.placeholderForCreatedAsset {
                    albumChangeRequest.addAssets([placeholder] as NSArray)
                }
            }) { success, error in
                if success,
                   let placeholder = assetPlaceholder,
                   let asset = PHAsset.fetchAssets(
                    withLocalIdentifiers: [placeholder.localIdentifier],
                    options: nil
                   ).firstObject {
                    continuation.resume(returning: asset)
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "PhotosLibraryManager", code: -2))
                }
            }
        }
    }
    
    /// Adds existing assets to an album
    func addAssets(_ assets: [PHAsset], to album: PHAssetCollection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) {
                    albumChangeRequest.addAssets(assets as NSArray)
                }
            }) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "PhotosLibraryManager", code: -3))
                }
            }
        }
    }
    
    // MARK: - Delete Operations
    
    /// Deletes an album (but not the photos in it)
    func deleteAlbum(_ album: PHAssetCollection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.deleteAssetCollections([album] as NSArray)
            }) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "PhotosLibraryManager", code: -4))
                }
            }
        }
    }
    
    /// Deletes assets
    func deleteAssets(_ assets: [PHAsset]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "PhotosLibraryManager", code: -5))
                }
            }
        }
    }
    
    /// Removes assets from an album (but doesn't delete them from library)
    func removeAssets(_ assets: [PHAsset], from album: PHAssetCollection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) {
                    albumChangeRequest.removeAssets(assets as NSArray)
                }
            }) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "PhotosLibraryManager", code: -6))
                }
            }
        }
    }
}
