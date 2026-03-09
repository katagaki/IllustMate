//
//  AlbumCover.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import Photos
import SwiftUI

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

        var body: some View {
            AlbumCover(name: album.name,
                       length: length,
                       picCount: album.picCount(),
                       albumCount: album.albumCount(),
                       primaryImage: primaryImage,
                       secondaryImage: secondaryImage,
                       tertiaryImage: tertiaryImage)
            .task(id: album.identifiableString()) {
                await loadRepresentativePhotos()
            }
        }

        private func loadRepresentativePhotos() async {
            var images: [Image?] = []
            if let coverPhoto = album.coverPhoto, let uiImage = UIImage(data: coverPhoto) {
                images.append(Image(uiImage: uiImage))
            }
            let thumbnails = await DataActor.shared.representativeThumbnails(forAlbumWithID: album.id)
            for thumbData in thumbnails {
                if let uiImage = UIImage(data: thumbData) {
                    images.append(Image(uiImage: uiImage))
                }
            }
            while images.count < 3 { images.append(nil) }
            primaryImage = images[0]
            secondaryImage = images[1]
            tertiaryImage = images[2]
        }
    }

    // MARK: - Async Cover (Photos Library Album)

    struct AsyncPhotosAlbumCover: View {

        var collection: PHAssetCollection
        var length: CGFloat?

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
            .task(id: collection.localIdentifier) {
                loadRepresentativePhotos()
            }
        }

        private func loadRepresentativePhotos() {
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 3
            let result = PHAsset.fetchAssets(in: collection, options: fetchOptions)

            let countOptions = PHFetchOptions()
            countOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            picCount = PHAsset.fetchAssets(in: collection, options: countOptions).count

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
