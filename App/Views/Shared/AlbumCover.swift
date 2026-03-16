//
//  AlbumCover.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import Photos
import SwiftUI

/// In-memory cache for album cover images (the 3 representative thumbnails per album).
@MainActor @Observable
final class AlbumCoverCache {
    static let shared = AlbumCoverCache()

    struct CoverImages: Sendable {
        let primary: Image?
        let secondary: Image?
        let tertiary: Image?
    }

    nonisolated(unsafe) private let cache = NSCache<NSString, CoverImagesBox>()

    /// Incremented each time new images are cached, causing observing views to re-check.
    private(set) var version: Int = 0

    init() {
        cache.countLimit = 200
    }

    nonisolated func images(forAlbumID id: String) -> CoverImages? {
        cache.object(forKey: id as NSString)?.value
    }

    nonisolated func setImages(_ images: CoverImages, forAlbumID id: String) {
        cache.setObject(CoverImagesBox(images), forKey: id as NSString)
    }

    func setImagesAndNotify(_ images: CoverImages, forAlbumID id: String) {
        cache.setObject(CoverImagesBox(images), forKey: id as NSString)
        version += 1
    }

    func removeImages(forAlbumID id: String) {
        cache.removeObject(forKey: id as NSString)
        pendingDiskDeletions.insert(id)
        version += 1
        Task {
            await CoverCacheActor.shared.deleteCover(forAlbumWithID: id)
            await MainActor.run {
                pendingDiskDeletions.remove(id)
            }
        }
    }

    /// Album IDs whose disk cache entries are being deleted asynchronously.
    /// `loadCover` skips the disk cache for these to avoid reloading stale data.
    private var pendingDiskDeletions: Set<String> = []

    /// Loads cover images for a single album into the cache.
    /// Checks the on-disk cache first, then falls back to the main database.
    /// Results are decoded off the main thread, then cached and notified.
    nonisolated func loadCover(for album: Album) async {
        // Skip if already in NSCache
        guard images(forAlbumID: album.id) == nil else { return }

        let albumID = album.id
        let hasCover = album.hasCoverPhoto
        let versionKey = album.identifiableString()

        // --- Layer 2: Disk cache ---
        let skipDiskCache = await MainActor.run { pendingDiskDeletions.contains(albumID) }
        if !skipDiskCache,
           let cached = await CoverCacheActor.shared.cachedCover(
            forAlbumWithID: albumID, versionKey: versionKey
        ) {
            let coverImages = decodeCoverImages(
                primary: cached.primary,
                secondary: cached.secondary,
                tertiary: cached.tertiary
            )
            setImages(coverImages, forAlbumID: albumID)
            await MainActor.run { version += 1 }
            return
        }

        // --- Layer 3: Main database ---
        let thumbnails = await DataActor.shared.representativeThumbnails(
            forAlbumWithID: albumID, limit: 3
        )

        var coverData: Data?
        if hasCover {
            coverData = await DataActor.shared.albumCoverData(forAlbumWithID: albumID)
        }

        // Assemble raw data blobs in display order
        var dataBlobs: [Data?] = []
        if hasCover, let coverData {
            dataBlobs.append(coverData)
        }
        for data in thumbnails {
            if dataBlobs.count >= 3 { break }
            dataBlobs.append(data)
        }
        while dataBlobs.count < 3 { dataBlobs.append(nil) }

        // Store in disk cache for next launch
        await CoverCacheActor.shared.storeCover(
            primary: dataBlobs[0], secondary: dataBlobs[1], tertiary: dataBlobs[2],
            forAlbumWithID: albumID, versionKey: versionKey
        )

        // Decode and store in NSCache
        let coverImages = decodeCoverImages(
            primary: dataBlobs[0], secondary: dataBlobs[1], tertiary: dataBlobs[2]
        )
        setImages(coverImages, forAlbumID: albumID)
        await MainActor.run {
            version += 1
        }
    }

    /// Decodes raw JPEG Data blobs into SwiftUI Images.
    private nonisolated func decodeCoverImages(
        primary: Data?, secondary: Data?, tertiary: Data?
    ) -> CoverImages {
        CoverImages(
            primary: primary.flatMap { UIImage(data: $0) }.map { Image(uiImage: $0) },
            secondary: secondary.flatMap { UIImage(data: $0) }.map { Image(uiImage: $0) },
            tertiary: tertiary.flatMap { UIImage(data: $0) }.map { Image(uiImage: $0) }
        )
    }
}

/// Wrapper so CoverImages can be stored in NSCache.
private final class CoverImagesBox: Sendable {
    let value: AlbumCoverCache.CoverImages
    init(_ value: AlbumCoverCache.CoverImages) { self.value = value }
}

struct AlbumCover: View {

    var name: String
    var length: CGFloat?
    var picCount: Int
    var albumCount: Int

    var primaryImage: Image?
    var secondaryImage: Image?
    var tertiaryImage: Image?

    init(
        name: String,
        length: CGFloat? = nil,
        picCount: Int = 0,
        albumCount: Int = 0,
        primaryImage: Image? = nil,
        secondaryImage: Image? = nil,
        tertiaryImage: Image? = nil
    ) {
        self.name = name
        self.length = length
        self.picCount = picCount
        self.albumCount = albumCount
        self.primaryImage = primaryImage
        self.secondaryImage = secondaryImage
        self.tertiaryImage = tertiaryImage
    }

    var body: some View {
        ZStack(alignment: .center) {
            GeometryReader { metrics in
                ZStack(alignment: .center) {
                    // Stack
                    if let tertiaryImage {
                        tertiaryImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: metrics.size.width * 0.92, height: metrics.size.height * 0.92)
                            .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous))
                            .rotationEffect(.degrees(-12.0))
                            .shadow(color: .black.opacity(0.15), radius: 2.0, x: 0.0, y: metrics.size.height * 0.01)
                            .padding(metrics.size.width * 0.04)
                    }
                    if let secondaryImage {
                        secondaryImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: metrics.size.width * 0.92, height: metrics.size.height * 0.92)
                            .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous))
                            .rotationEffect(.degrees(10.0))
                            .shadow(color: .black.opacity(0.15), radius: 3.0, x: 0.0, y: metrics.size.height * 0.02)
                            .padding(metrics.size.width * 0.04)
                    }

                    if let primaryImage {
                        ZStack(alignment: .bottom) {
                            primaryImage
                                .resizable()
                                .scaledToFill()

                            if metrics.size.width >= 80 {
                                // Darkening gradient at bottom
                                LinearGradient(colors: [.clear, .black.opacity(0.65)],
                                               startPoint: .center,
                                               endPoint: .bottom)
                            }
                        }
                        .frame(width: metrics.size.width * 0.92, height: metrics.size.height * 0.92)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.35), radius: 4.0, x: 0.0, y: metrics.size.height * 0.03)
                        .padding(metrics.size.width * 0.04)
                    } else {
                        // Use color for empty albums
                        let colors = Color.gradient(from: name)
                        RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous)
                            .fill(LinearGradient(colors: [colors.primary, colors.secondary],
                                                 startPoint: .topLeading,
                                                 endPoint: .bottomTrailing))
                            .frame(width: metrics.size.width * 0.92, height: metrics.size.height * 0.92)
                            .shadow(color: .black.opacity(0.35), radius: 4.0, x: 0.0, y: metrics.size.height * 0.03)
                            .padding(metrics.size.width * 0.04)
                    }
                }
                .overlay(alignment: .bottom) {
                    if metrics.size.width >= 80 {
                        AlbumItemCount(picCount: picCount, albumCount: albumCount)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5),
                                    radius: 2.0,
                                    x: 0.0, y: 1.0)
                            .padding(.bottom, metrics.size.height * 0.1)
                            .allowsHitTesting(false)
                    }
                }
            }
            .transition(.opacity.animation(.smooth.speed(2)))
        }
        .scaledToFit()
        .frame(width: length, height: length)
    }

    // MARK: - Async Cover (Local Database)

    struct AsyncAlbumCover: View {

        var album: Album
        var length: CGFloat?

        @State private var primaryImage: Image?
        @State private var secondaryImage: Image?
        @State private var tertiaryImage: Image?
        @State private var isLoaded = false

        var body: some View {
            AlbumCover(name: album.name,
                       length: length,
                       picCount: album.picCount(),
                       albumCount: album.albumCount(),
                       primaryImage: primaryImage,
                       secondaryImage: secondaryImage,
                       tertiaryImage: tertiaryImage)
            .onChange(of: AlbumCoverCache.shared.version) {
                // If NSCache no longer has our entry, reset so we reload
                if AlbumCoverCache.shared.images(forAlbumID: album.id) == nil {
                    guard isLoaded else { return }
                    isLoaded = false
                    primaryImage = nil
                    secondaryImage = nil
                    tertiaryImage = nil
                    Task {
                        await AlbumCoverCache.shared.loadCover(for: album)
                    }
                } else {
                    loadFromCache()
                }
            }
            .onChange(of: album.identifiableString()) {
                isLoaded = false
                loadFromCache()
            }
            .task(id: album.identifiableString()) {
                // Check cache first
                if loadFromCache() { return }
                // Load this album's cover on demand
                await AlbumCoverCache.shared.loadCover(for: album)
            }
        }

        @discardableResult
        private func loadFromCache() -> Bool {
            guard !isLoaded else { return true }
            if let cached = AlbumCoverCache.shared.images(forAlbumID: album.id) {
                primaryImage = cached.primary
                secondaryImage = cached.secondary
                tertiaryImage = cached.tertiary
                isLoaded = true
                return true
            }
            return false
        }
    }

    // MARK: - Async Cover (Photos Library Album)

    struct AsyncPhotosAlbumCover: View {

        var collection: PHAssetCollection
        var length: CGFloat?
        var refreshID: Int = 0

        @Environment(\.displayScale) private var displayScale

        @State private var primaryImage: Image?
        @State private var secondaryImage: Image?
        @State private var tertiaryImage: Image?
        @State private var picCount: Int = 0

        var body: some View {
            AlbumCover(name: collection.localizedTitle ?? "",
                       length: length,
                       picCount: picCount,
                       albumCount: 0,
                       primaryImage: primaryImage,
                       secondaryImage: secondaryImage,
                       tertiaryImage: tertiaryImage)
            .task(id: "\(collection.localIdentifier)-\(refreshID)") {
                loadRepresentativePhotos()
            }
        }

        private func loadRepresentativePhotos() {
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let estimated = collection.estimatedAssetCount
            if estimated != NSNotFound {
                picCount = estimated
                fetchOptions.fetchLimit = 3
            }

            let result = PHAsset.fetchAssets(in: collection, options: fetchOptions)

            if estimated == NSNotFound {
                picCount = result.count
            }

            let manager = PHCachingImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            let coverLength = length ?? 200
            let targetSize = CGSize(width: coverLength * displayScale,
                                    height: coverLength * displayScale)

            result.enumerateObjects { asset, index, _ in
                manager.requestImage(for: asset, targetSize: targetSize,
                                     contentMode: .aspectFill, options: options) { uiImage, _ in
                    if let uiImage {
                        let image = Image(uiImage: uiImage)
                        DispatchQueue.main.async {
                            switch index {
                            case 0: self.primaryImage = image
                            case 1: self.secondaryImage = image
                            case 2: self.tertiaryImage = image
                            default: break
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Async Cover (Photos Library Folder)

    struct AsyncPhotosFolderCover: View {

        var folder: PHCollectionList
        var length: CGFloat?

        var body: some View {
            AlbumCover(name: folder.localizedTitle ?? "",
                       length: length,
                       picCount: 0,
                       albumCount: PHCollection.fetchCollections(in: folder, options: nil).count)
        }
    }
}

// MARK: - Item Count

struct AlbumItemCount: View {

    let picCount: Int
    let albumCount: Int

    init(picCount: Int, albumCount: Int) {
        self.picCount = picCount
        self.albumCount = albumCount
    }

    init(of album: Album) {
        self.picCount = album.picCount()
        self.albumCount = album.albumCount()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 6.0) {
            if picCount > 0 || albumCount > 0 {
                if picCount > 0 {
                    iconAndLabel(picCount, systemImage: "photo.fill")
                }
                if albumCount > 0 {
                    iconAndLabel(albumCount, systemImage: "rectangle.stack.fill")
                }
            } else {
                iconAndLabel(0, systemImage: "photo.fill")
                iconAndLabel(0, systemImage: "rectangle.stack.fill")
            }
        }
        .font(.system(size: 10.0, weight: .semibold, design: .rounded))
    }

    func iconAndLabel(_ count: Int, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 2.0) {
            Image(systemName: systemImage)
            Text(String(count))
        }
    }
}
