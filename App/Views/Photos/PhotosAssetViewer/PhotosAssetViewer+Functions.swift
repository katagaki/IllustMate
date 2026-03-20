//
//  PhotosAssetViewer+Functions.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import AVKit
import Photos
import SwiftUI

extension PhotosAssetViewer {

    @ViewBuilder
    var mainContent: some View {
        if isLandscape {
            // Landscape: vertical carousel on the left, image fills remaining space
            HStack(spacing: 0.0) {
                if photosViewer.allAssets.count > 1 {
                    PhotosAssetCarouselStripVertical()
                        .padding(.vertical, -8.0)
                }
                imageContent
            }
            .padding(8.0)
            .padding(.leading, 40.0)
        } else {
            // Portrait: image on top, horizontal carousel at bottom
            VStack(alignment: .center, spacing: 0.0) {
                imageContent

                if photosViewer.allAssets.count > 1 {
                    PhotosAssetCarouselStrip()
                        .padding(.horizontal, -20.0)
                }
            }
            .padding([.top, .horizontal], 20.0)
        }
    }

    var imageContent: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                // Show thumbnail as placeholder
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 8.0))
                        .opacity(isFullImageLoaded ? 0 : 1)
                }
                // Show full image when loaded
                if let fullImage, isFullImageLoaded {
                    Image(uiImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 8.0))
                }
            }

            // Image size overlay
            if showImageSize, let displayedImage = fullImage {
                HStack(alignment: .center, spacing: 2.0) {
                    Text(verbatim: "\(Int(displayedImage.size.width * displayedImage.scale))")
                    Text(verbatim: "×")
                    Text(verbatim: "\(Int(displayedImage.size.height * displayedImage.scale))")
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.bar, in: .capsule)
                .padding(8)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, isLandscape ? 4 : 20)
        .padding(.bottom, isLandscape ? 0 : 20)
        .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
        .zIndex(1)
        .offset(displayOffset)
        .scaleEffect(CGSize(width: magnification, height: magnification),
                     anchor: magnificationAnchor)
        .onTapGesture {
            withAnimation(.smooth.speed(2)) {
                showImageSize.toggle()
            }
        }
    }

    func startPictureInPicture() {
        guard let image = currentImage else { return }

        let assetToRestore = photosViewer.displayedAsset
        let assetsToRestore = photosViewer.allAssets
        let indexToRestore = photosViewer.currentIndex

        pipManager.start(with: image) { [photosViewer] in
            if let asset = assetToRestore {
                photosViewer.allAssets = assetsToRestore
                photosViewer.currentIndex = indexToRestore
                photosViewer.displayedAsset = asset
            }
        }
    }

    func loadThumbnail() {
        let manager = PHCachingImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        let targetSize = CGSize(width: viewSize.width * displayScale,
                                height: viewSize.height * displayScale)

        manager.requestImage(for: currentAsset, targetSize: targetSize,
                             contentMode: .aspectFit, options: options) { result, _ in
            if let result {
                DispatchQueue.main.async {
                    self.thumbnail = result
                }
            }
        }
    }

    func loadFullImage() async {
        await withCheckedContinuation { continuation in
            let manager = PHCachingImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            manager.requestImage(for: currentAsset, targetSize: PHImageManagerMaximumSize,
                                 contentMode: .default, options: options) { result, _ in
                if let result {
                    DispatchQueue.main.async {
                        self.fullImage = result
                        self.isFullImageLoaded = true
                    }
                }
                continuation.resume()
            }
        }
    }
}
