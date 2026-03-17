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

    /// Coalesces rapid version increments so SwiftUI doesn't re-evaluate every
    /// observing view once per loaded cover.
    private var versionBumpPending = false

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
        scheduleVersionBump()
    }

    /// Coalesces multiple version bumps into a single update, reducing the number of
    /// SwiftUI view re-evaluations when many covers finish loading close together.
    private func scheduleVersionBump() {
        guard !versionBumpPending else { return }
        versionBumpPending = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            self.versionBumpPending = false
            self.version += 1
        }
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
            await MainActor.run { scheduleVersionBump() }
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
            scheduleVersionBump()
        }
    }

    /// Loads covers for a list of albums progressively, processing them in small
    /// batches to avoid saturating the database actors and main thread.
    nonisolated func loadCovers(for albums: [Album]) async {
        let maxConcurrent = 4
        await withTaskGroup(of: Void.self) { group in
            var iterator = albums.makeIterator()

            // Seed with initial batch
            for _ in 0..<min(maxConcurrent, albums.count) {
                guard let album = iterator.next() else { break }
                group.addTask {
                    await self.loadCover(for: album)
                }
            }

            // As each finishes, start the next
            for await _ in group {
                if let album = iterator.next() {
                    group.addTask {
                        await self.loadCover(for: album)
                    }
                }
            }
        }
    }

    /// Decodes raw JPEG Data blobs into SwiftUI Images.
    /// Forces pixel decompression off the main thread so the render pass doesn't stall.
    private nonisolated func decodeCoverImages(
        primary: Data?, secondary: Data?, tertiary: Data?
    ) -> CoverImages {
        CoverImages(
            primary: primary.flatMap { Self.decodedImage(from: $0) },
            secondary: secondary.flatMap { Self.decodedImage(from: $0) },
            tertiary: tertiary.flatMap { Self.decodedImage(from: $0) }
        )
    }

    /// Decodes JPEG data into a SwiftUI Image with pixels fully decompressed.
    /// By drawing through UIGraphicsImageRenderer, the backing CGImage is forced
    /// to decode immediately rather than lazily during the first render on the main thread.
    private nonisolated static func decodedImage(from data: Data) -> Image? {
        guard let uiImage = UIImage(data: data) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = uiImage.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: uiImage.size, format: format)
        let decoded = renderer.image { _ in
            uiImage.draw(at: .zero)
        }
        return Image(uiImage: decoded)
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
        Canvas { context, size in
            let itemCountTag = "itemCount"
            // The canvas is physically larger than the layout size (via frame/padding)
            // to prevent clipping of rotated cards and shadows. Scale factor undoes
            // the oversizing so cards appear at the intended 92% of layout size.
            let scale: CGFloat = 1.0 / 1.16
            let cardW = size.width * 0.92 * scale
            let cardH = size.height * 0.92 * scale
            let cornerRadius = size.height * 0.12 * scale
            let cardRect = CGRect(
                x: (size.width - cardW) / 2,
                y: (size.height - cardH) / 2,
                width: cardW,
                height: cardH
            )
            let cardPath = Path(
                roundedRect: cardRect,
                cornerRadius: cornerRadius,
                style: .continuous
            )

            let logicalH = size.height * scale
            let logicalW = size.width * scale

            // --- Tertiary image (back, rotated -12°) ---
            if let tertiaryImage {
                drawRotatedCard(
                    context: context, size: size, image: tertiaryImage,
                    cardW: cardW, cardH: cardH, cornerRadius: cornerRadius,
                    angle: .degrees(-12),
                    shadowColor: .black.opacity(0.15), shadowRadius: 2, shadowY: logicalH * 0.01
                )
            }

            // --- Secondary image (middle, rotated +10°) ---
            if let secondaryImage {
                drawRotatedCard(
                    context: context, size: size, image: secondaryImage,
                    cardW: cardW, cardH: cardH, cornerRadius: cornerRadius,
                    angle: .degrees(10),
                    shadowColor: .black.opacity(0.15), shadowRadius: 3, shadowY: logicalH * 0.02
                )
            }

            // --- Primary image (front) or gradient placeholder ---
            if let primaryImage {
                var front = context
                front.addFilter(.shadow(
                    color: .black.opacity(0.25), radius: 2, x: 0, y: logicalH * 0.015
                ))
                front.drawLayer { ctx in
                    ctx.clip(to: cardPath)

                    // Draw image filling the card rect
                    let resolved = ctx.resolve(primaryImage)
                    let srcSize = resolved.size
                    let scale = max(cardW / srcSize.width, cardH / srcSize.height)
                    let drawW = srcSize.width * scale
                    let drawH = srcSize.height * scale
                    let drawRect = CGRect(
                        x: cardRect.midX - drawW / 2,
                        y: cardRect.midY - drawH / 2,
                        width: drawW,
                        height: drawH
                    )
                    ctx.draw(resolved, in: drawRect)

                    // Darkening gradient at bottom
                    if logicalW >= 80 {
                        let gradientRect = CGRect(
                            x: cardRect.minX,
                            y: cardRect.midY,
                            width: cardW,
                            height: cardH / 2
                        )
                        ctx.fill(
                            Path(gradientRect),
                            with: .linearGradient(
                                Gradient(colors: [.clear, .black.opacity(0.65)]),
                                startPoint: CGPoint(x: gradientRect.midX, y: gradientRect.minY),
                                endPoint: CGPoint(x: gradientRect.midX, y: gradientRect.maxY)
                            )
                        )
                    }

                    // Thin border stroke
                    ctx.stroke(cardPath, with: .color(.primary.opacity(0.15)), lineWidth: 0.5)
                }
            } else {
                // Empty album gradient placeholder
                let gradColors = Color.gradient(from: name)
                var front = context
                front.addFilter(.shadow(
                    color: .black.opacity(0.25), radius: 2, x: 0, y: logicalH * 0.015
                ))
                front.fill(
                    cardPath,
                    with: .linearGradient(
                        Gradient(colors: [gradColors.primary, gradColors.secondary]),
                        startPoint: cardRect.origin,
                        endPoint: CGPoint(x: cardRect.maxX, y: cardRect.maxY)
                    )
                )
            }

            // --- Item count overlay ---
            if logicalW >= 80,
               let resolved = context.resolveSymbol(id: itemCountTag) {
                let countOrigin = CGPoint(
                    x: size.width / 2,
                    y: size.height / 2 + logicalH * (0.5 - 0.16)
                )
                context.draw(resolved, at: countOrigin, anchor: .center)
            }
        } symbols: {
            AlbumItemCount(picCount: picCount, albumCount: albumCount)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .tag("itemCount")
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(width: length.map { $0 * 1.16 }, height: length.map { $0 * 1.16 })
        .padding(length.map { $0 * -0.08 } ?? 0)
        .transition(.opacity.animation(.smooth.speed(2)))
    }

    /// Draws a rotated card image into the Canvas context (used for secondary/tertiary stack cards).
    // swiftlint:disable:next function_parameter_count
    private func drawRotatedCard(
        context: GraphicsContext,
        size: CGSize,
        image: Image,
        cardW: CGFloat,
        cardH: CGFloat,
        cornerRadius: CGFloat,
        angle: Angle,
        shadowColor: Color,
        shadowRadius: CGFloat,
        shadowY: CGFloat
    ) {
        let cardRect = CGRect(
            x: (size.width - cardW) / 2,
            y: (size.height - cardH) / 2,
            width: cardW,
            height: cardH
        )
        let cardPath = Path(
            roundedRect: cardRect,
            cornerRadius: cornerRadius,
            style: .continuous
        )
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        var ctx = context
        ctx.addFilter(.shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY))
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: angle)
        ctx.translateBy(x: -center.x, y: -center.y)
        ctx.drawLayer { inner in
            inner.clip(to: cardPath)
            let resolved = inner.resolve(image)
            let srcSize = resolved.size
            let scale = max(cardW / srcSize.width, cardH / srcSize.height)
            let drawW = srcSize.width * scale
            let drawH = srcSize.height * scale
            let drawRect = CGRect(
                x: cardRect.midX - drawW / 2,
                y: cardRect.midY - drawH / 2,
                width: drawW,
                height: drawH
            )
            inner.draw(resolved, in: drawRect)
        }
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
                if AlbumCoverCache.shared.images(forAlbumID: album.id) == nil {
                    guard isLoaded else { return }
                    isLoaded = false
                    primaryImage = nil
                    secondaryImage = nil
                    tertiaryImage = nil
                    // Reload this single cover (e.g. after eviction or invalidation)
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
            .onAppear {
                loadFromCache()
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
