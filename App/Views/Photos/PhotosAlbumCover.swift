//
//  PhotosAlbumCover.swift
//  PicMate
//
//  Created on 2026/02/28.
//

import Photos
import SwiftUI

struct PhotosAlbumCover: View {

    var name: String
    var length: CGFloat?
    var picCount: Int
    var albumCount: Int

    var primaryImage: Image?
    var secondaryImage: Image?
    var tertiaryImage: Image?

    var body: some View {
        ZStack(alignment: .center) {
            GeometryReader { metrics in
                ZStack(alignment: .center) {
                    if let tertiaryImage {
                        tertiaryImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: metrics.size.width * 0.92, height: metrics.size.height * 0.92)
                            .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.12,
                                                        style: .continuous))
                            .rotationEffect(.degrees(-12.0))
                            .shadow(color: .black.opacity(0.15), radius: 2.0,
                                    x: 0.0, y: metrics.size.height * 0.01)
                            .padding(metrics.size.width * 0.04)
                    }
                    if let secondaryImage {
                        secondaryImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: metrics.size.width * 0.92, height: metrics.size.height * 0.92)
                            .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.12,
                                                        style: .continuous))
                            .rotationEffect(.degrees(10.0))
                            .shadow(color: .black.opacity(0.15), radius: 3.0,
                                    x: 0.0, y: metrics.size.height * 0.02)
                            .padding(metrics.size.width * 0.04)
                    }

                    if let primaryImage {
                        ZStack(alignment: .bottom) {
                            primaryImage
                                .resizable()
                                .scaledToFill()

                            if metrics.size.width >= 80 {
                                Group {
                                    ForEach(1...5, id: \.self) { index in
                                        primaryImage
                                            .resizable()
                                            .scaledToFill()
                                            .blur(radius: CGFloat(index * index) * 0.8)
                                            .mask {
                                                LinearGradient(
                                                    stops: [
                                                        .init(color: .clear,
                                                              location: 0.5 + Double(index - 1) * 0.1),
                                                        .init(color: .black, location: 1.0)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            }
                                    }
                                }
                                LinearGradient(colors: [.clear, .black.opacity(0.65)],
                                               startPoint: .center,
                                               endPoint: .bottom)
                            }
                        }
                        .frame(width: metrics.size.width * 0.92, height: metrics.size.height * 0.92)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.12,
                                                    style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.35), radius: 4.0,
                                x: 0.0, y: metrics.size.height * 0.03)
                        .padding(metrics.size.width * 0.04)
                    } else {
                        let colors = Color.gradient(from: name)
                        RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous)
                            .fill(LinearGradient(colors: [colors.primary, colors.secondary],
                                                 startPoint: .topLeading,
                                                 endPoint: .bottomTrailing))
                            .frame(width: metrics.size.width * 0.92, height: metrics.size.height * 0.92)
                            .shadow(color: .black.opacity(0.35), radius: 4.0,
                                    x: 0.0, y: metrics.size.height * 0.03)
                            .padding(metrics.size.width * 0.04)
                    }
                }
                .overlay(alignment: .bottom) {
                    if metrics.size.width >= 80 {
                        PhotosAlbumItemCount(picCount: picCount, albumCount: albumCount)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2.0, x: 0.0, y: 1.0)
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
}

// MARK: - Async Cover (loads representative thumbnails from PHAssetCollection)

struct AsyncPhotosAlbumCover: View {

    var collection: PHAssetCollection
    var length: CGFloat?

    @State private var primaryImage: Image?
    @State private var secondaryImage: Image?
    @State private var tertiaryImage: Image?
    @State private var picCount: Int = 0

    var body: some View {
        PhotosAlbumCover(
            name: collection.localizedTitle ?? "",
            length: length,
            picCount: picCount,
            albumCount: 0,
            primaryImage: primaryImage,
            secondaryImage: secondaryImage,
            tertiaryImage: tertiaryImage
        )
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

        // Get total count (separate fetch without limit)
        let countOptions = PHFetchOptions()
        countOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        picCount = PHAsset.fetchAssets(in: collection, options: countOptions).count

        let manager = PHCachingImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        let targetSize = CGSize(width: 200, height: 200)

        var images: [Image?] = []
        result.enumerateObjects { asset, _, _ in
            manager.requestImage(for: asset, targetSize: targetSize,
                                 contentMode: .aspectFill, options: options) { uiImage, _ in
                if let uiImage {
                    DispatchQueue.main.async {
                        images.append(Image(uiImage: uiImage))
                        updateImages(images)
                    }
                }
            }
        }
    }

    private func updateImages(_ images: [Image?]) {
        if images.count >= 1 { primaryImage = images[0] }
        if images.count >= 2 { secondaryImage = images[1] }
        if images.count >= 3 { tertiaryImage = images[2] }
    }
}

// MARK: - Async Folder Cover (gradient-based, no photos)

struct AsyncPhotosFolderCover: View {

    var folder: PHCollectionList
    var length: CGFloat?

    var body: some View {
        PhotosAlbumCover(
            name: folder.localizedTitle ?? "",
            length: length,
            picCount: 0,
            albumCount: childCount(),
            primaryImage: nil,
            secondaryImage: nil,
            tertiaryImage: nil
        )
    }

    private func childCount() -> Int {
        PHCollection.fetchCollections(in: folder, options: nil).count
    }
}

// MARK: - Item Count

struct PhotosAlbumItemCount: View {

    let picCount: Int
    let albumCount: Int

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
