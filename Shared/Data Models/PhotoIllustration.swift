//
//  PhotoIllustration.swift
//  IllustMate
//
//  Wrapper for Photos library assets
//

import Foundation
import Photos
import UIKit

/// Represents a PHAsset (photo) from Photos library
class PhotoIllustration: Identifiable, Hashable {
    
    let id: String
    let asset: PHAsset
    let name: String
    let dateAdded: Date
    private let photosManager = PhotosLibraryManager.shared
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.name = asset.value(forKey: "filename") as? String ?? "Photo"
        self.dateAdded = asset.creationDate ?? Date()
    }
    
    /// Load thumbnail asynchronously
    func thumbnail() async -> UIImage? {
        return await photosManager.loadThumbnail(for: asset)
    }
    
    /// Load full image asynchronously
    func loadImage() async -> UIImage? {
        return await photosManager.loadImage(for: asset)
    }
    
    /// Load image data asynchronously
    func loadImageData() async -> Data? {
        return await photosManager.loadImageData(for: asset)
    }
    
    // MARK: - Hashable
    
    static func == (lhs: PhotoIllustration, rhs: PhotoIllustration) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
