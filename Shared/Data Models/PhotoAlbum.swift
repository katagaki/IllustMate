//
//  PhotoAlbum.swift
//  IllustMate
//
//  Wrapper for Photos library collections
//

import Foundation
import Photos
import SwiftUI
import UIKit

/// Represents either a folder (PHCollectionList) or an album (PHAssetCollection) from Photos library
class PhotoAlbum: Identifiable, Hashable {
    
    enum AlbumType {
        case folder(PHCollectionList)
        case album(PHAssetCollection)
    }
    
    let id: String
    let name: String
    let type: AlbumType
    private let photosManager = PhotosLibraryManager.shared
    
    // For folders that have an album with the same name inside them
    private var sameNameAlbum: PHAssetCollection?
    
    init(folder: PHCollectionList) {
        self.id = folder.localIdentifier
        self.name = folder.localizedTitle ?? "Untitled Folder"
        self.type = .folder(folder)
        
        // Check for same-name album
        self.sameNameAlbum = photosManager.detectSameNameAlbum(in: folder)
    }
    
    init(album: PHAssetCollection) {
        self.id = album.localIdentifier
        self.name = album.localizedTitle ?? "Untitled Album"
        self.type = .album(album)
        self.sameNameAlbum = nil
    }
    
    // MARK: - Child Collections
    
    /// Returns child albums (for folders) or empty array (for albums)
    func childAlbums() -> [PhotoAlbum] {
        switch type {
        case .folder(let folder):
            let albums = photosManager.fetchUserAlbums(in: folder)
            let folders = photosManager.fetchUserFolders(in: folder)
            
            // Filter out the same-name album if it exists
            let filteredAlbums = albums.filter { album in
                if let sameNameAlbum = sameNameAlbum {
                    return album.localIdentifier != sameNameAlbum.localIdentifier
                }
                return true
            }
            
            // Convert to PhotoAlbum objects
            let albumWrappers = filteredAlbums.map { PhotoAlbum(album: $0) }
            let folderWrappers = folders.map { PhotoAlbum(folder: $0) }
            
            return folderWrappers + albumWrappers
        case .album:
            return []
        }
    }
    
    // MARK: - Photos
    
    /// Returns photos in this album/folder
    func illustrations(sortOrder: SortOrder = .reverse) -> [PhotoIllustration] {
        let assets: [PHAsset]
        
        switch type {
        case .folder(let folder):
            // If folder has an album with the same name, get photos from that album
            if let sameNameAlbum = sameNameAlbum {
                assets = photosManager.fetchAssets(in: sameNameAlbum, sortOrder: sortOrder)
            } else {
                assets = []
            }
        case .album(let album):
            assets = photosManager.fetchAssets(in: album, sortOrder: sortOrder)
        }
        
        return assets.map { PhotoIllustration(asset: $0) }
    }
    
    // MARK: - Counts
    
    func albumCount() -> Int {
        switch type {
        case .folder(let folder):
            var count = photosManager.albumCount(in: folder)
            // Subtract 1 if there's a same-name album (since we hide it)
            if sameNameAlbum != nil {
                count = max(0, count - 1)
            }
            // Also count nested folders
            let folders = photosManager.fetchUserFolders(in: folder)
            return count + folders.count
        case .album:
            return 0
        }
    }
    
    func illustrationCount() -> Int {
        switch type {
        case .folder(let folder):
            if let sameNameAlbum = sameNameAlbum {
                return photosManager.assetCount(in: sameNameAlbum)
            }
            return 0
        case .album(let album):
            return photosManager.assetCount(in: album)
        }
    }
    
    // MARK: - Cover Image
    
    func cover() -> UIImage {
        // Try to get the first photo as cover
        if let firstPhoto = illustrations(sortOrder: .forward).first {
            // Synchronously request a small thumbnail for the cover
            let semaphore = DispatchSemaphore(value: 0)
            var coverImage: UIImage?
            
            Task {
                coverImage = await photosManager.loadThumbnail(for: firstPhoto.asset)
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .now() + 2.0)
            
            if let image = coverImage {
                return image.scalePreservingAspectRatio(targetSize: CGSize(width: 60.0, height: 60.0))
            }
        }
        
        return UIImage(named: "Album.Generic")!
    }
    
    func representativePhotos() -> [Image?] {
        var imagesToReturn: [Image?] = []
        let illustrations = self.illustrations(sortOrder: .forward)
        
        // Get first 3 photos
        for i in 0..<min(3, illustrations.count) {
            let semaphore = DispatchSemaphore(value: 0)
            var photoImage: UIImage?
            
            Task {
                photoImage = await photosManager.loadThumbnail(for: illustrations[i].asset)
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .now() + 1.0)
            
            if let image = photoImage {
                imagesToReturn.append(Image(uiImage: image))
            }
        }
        
        // Pad with nil to ensure we always return 3 elements
        while imagesToReturn.count < 3 {
            imagesToReturn.append(nil)
        }
        
        return imagesToReturn
    }
    
    func identifiableString() -> String {
        return "\(id)-\(albumCount())-\(illustrationCount())"
    }
    
    // MARK: - Underlying Collection
    
    var assetCollection: PHAssetCollection? {
        switch type {
        case .album(let album):
            return album
        case .folder:
            return sameNameAlbum
        }
    }
    
    var collectionList: PHCollectionList? {
        switch type {
        case .folder(let folder):
            return folder
        case .album:
            return nil
        }
    }
    
    // MARK: - Hashable
    
    static func == (lhs: PhotoAlbum, rhs: PhotoAlbum) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
