//
//  PhotosDataActor.swift
//  IllustMate
//
//  Data actor for Photos library operations
//

import Foundation
import Photos
import SwiftUI

actor PhotosDataActor {
    
    private let photosManager: PhotosLibraryManager
    
    init() {
        self.photosManager = PhotosLibraryManager.shared
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> PHAuthorizationStatus {
        return await photosManager.requestAuthorization()
    }
    
    func checkAuthorizationStatus() -> PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    // MARK: - Albums
    
    func albums(sortedBy sortType: SortType) -> [PhotoAlbum] {
        let topLevelFolders = photosManager.fetchUserFolders()
        let topLevelAlbums = photosManager.fetchUserAlbums()
        
        let folderWrappers = topLevelFolders.map { PhotoAlbum(folder: $0) }
        let albumWrappers = topLevelAlbums.map { PhotoAlbum(album: $0) }
        
        let allAlbums = folderWrappers + albumWrappers
        return sortAlbum(allAlbums, sortedBy: sortType)
    }
    
    func albums(in album: PhotoAlbum?, sortedBy sortType: SortType) -> [PhotoAlbum] {
        guard let album = album else {
            return albums(sortedBy: sortType)
        }
        
        let childAlbums = album.childAlbums()
        return sortAlbum(childAlbums, sortedBy: sortType)
    }
    
    func album(for id: String) -> PhotoAlbum? {
        // Try to fetch as album
        if let collection = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [id],
            options: nil
        ).firstObject {
            return PhotoAlbum(album: collection)
        }
        
        // Try to fetch as folder
        if let collectionList = PHCollectionList.fetchCollectionLists(
            withLocalIdentifiers: [id],
            options: nil
        ).firstObject {
            return PhotoAlbum(folder: collectionList)
        }
        
        return nil
    }
    
    func createAlbum(_ albumName: String) async throws -> PhotoAlbum {
        let collection = try await photosManager.createAlbum(named: albumName.trimmingCharacters(in: .whitespaces))
        return PhotoAlbum(album: collection)
    }
    
    func renameAlbum(withID albumID: String, to newName: String) async throws {
        // PHAssetCollection doesn't support renaming directly through PhotoKit
        // This would require using the Photos framework's change request
        // For now, this is a limitation of the Photos library
        throw NSError(domain: "PhotosDataActor", code: -1, 
                     userInfo: [NSLocalizedDescriptionKey: "Renaming albums is not supported by PhotoKit"])
    }
    
    func sortAlbum(_ albums: [PhotoAlbum], sortedBy sortType: SortType) -> [PhotoAlbum] {
        switch sortType {
        case .nameAscending: 
            return albums.sorted(by: { $0.name < $1.name })
        case .nameDescending: 
            return albums.sorted(by: { $0.name > $1.name })
        case .sizeAscending:
            return albums.sorted(by: {
                objectCount(inAlbum: $0) < objectCount(inAlbum: $1)
            })
        case .sizeDescending:
            return albums.sorted(by: {
                objectCount(inAlbum: $0) > objectCount(inAlbum: $1)
            })
        }
    }
    
    func objectCount(inAlbum album: PhotoAlbum) -> Int {
        return album.albumCount() + album.illustrationCount()
    }
    
    func albumCount(inAlbum album: PhotoAlbum) -> Int {
        return album.albumCount()
    }
    
    func illustrationCount() -> Int {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let allPhotos = PHAsset.fetchAssets(with: fetchOptions)
        return allPhotos.count
    }
    
    func illustrationCount(inAlbum album: PhotoAlbum) -> Int {
        return album.illustrationCount()
    }
    
    func deleteAlbum(withID albumID: String) async throws {
        if let album = self.album(for: albumID),
           let assetCollection = album.assetCollection {
            try await photosManager.deleteAlbum(assetCollection)
        }
    }
    
    // MARK: - Illustrations
    
    func illustrations(in album: PhotoAlbum?, order: SortOrder) -> [PhotoIllustration] {
        if let album = album {
            return album.illustrations(sortOrder: order)
        } else {
            // Fetch all photos from library
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: order == .forward)]
            
            let allPhotos = PHAsset.fetchAssets(with: fetchOptions)
            var illustrations: [PhotoIllustration] = []
            
            allPhotos.enumerateObjects { asset, _, _ in
                illustrations.append(PhotoIllustration(asset: asset))
            }
            
            return illustrations
        }
    }
    
    func illustration(for id: String) -> PhotoIllustration? {
        if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject {
            return PhotoIllustration(asset: asset)
        }
        return nil
    }
    
    func createIllustration(_ name: String, data: Data, inAlbum album: PhotoAlbum? = nil) async throws {
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "PhotosDataActor", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        
        if let album = album, let assetCollection = album.assetCollection {
            _ = try await photosManager.addImage(image, to: assetCollection)
        } else {
            // Add to library without album
            _ = try await photosManager.addImage(image, to: PHAssetCollection())
        }
    }
    
    func addIllustrations(withIDs illustrationIDs: [String], toAlbum album: PhotoAlbum) async throws {
        guard let assetCollection = album.assetCollection else {
            throw NSError(domain: "PhotosDataActor", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Album doesn't support adding photos"])
        }
        
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: illustrationIDs, options: nil)
        var assetArray: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            assetArray.append(asset)
        }
        
        try await photosManager.addAssets(assetArray, to: assetCollection)
    }
    
    func addIllustration(withID illustrationID: String, toAlbum album: PhotoAlbum) async throws {
        try await addIllustrations(withIDs: [illustrationID], toAlbum: album)
    }
    
    func removeParentAlbum(forIllustrationWithID illustrationID: String, fromAlbum album: PhotoAlbum) async throws {
        guard let assetCollection = album.assetCollection,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [illustrationID], options: nil).firstObject else {
            return
        }
        
        try await photosManager.removeAssets([asset], from: assetCollection)
    }
    
    func removeParentAlbum(forIllustrationsWithIDs illustrationIDs: [String], fromAlbum album: PhotoAlbum) async throws {
        guard let assetCollection = album.assetCollection else {
            return
        }
        
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: illustrationIDs, options: nil)
        var assetArray: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            assetArray.append(asset)
        }
        
        try await photosManager.removeAssets(assetArray, from: assetCollection)
    }
    
    func deleteIllustration(withID illustrationID: String) async throws {
        if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [illustrationID], options: nil).firstObject {
            try await photosManager.deleteAssets([asset])
        }
    }
    
    func deleteIllustrations(withIDs illustrationIDs: [String]) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: illustrationIDs, options: nil)
        var assetArray: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            assetArray.append(asset)
        }
        
        try await photosManager.deleteAssets(assetArray)
    }
}

let photosActor = PhotosDataActor()
