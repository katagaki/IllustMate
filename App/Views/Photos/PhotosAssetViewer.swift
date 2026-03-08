//
//  PhotosAssetViewer.swift
//  PicMate
//
//  Created on 2026/02/28.
//

import Photos
import SwiftUI

struct PhotosAssetViewer: View {

    @Environment(\.colorScheme) var colorScheme
    @Environment(PhotosViewerManager.self) var photosViewer

    let asset: PHAsset

    @Environment(\.displayScale) private var displayScale

    @State private var thumbnail: UIImage?
    @State private var fullImage: UIImage?
    @State private var isFullImageLoaded: Bool = false
    @State private var showImageSize: Bool = true
    @State private var magnification: CGFloat = 1.0
    @State private var magnificationAnchor: UnitPoint = .center
    @State private var displayOffset: CGSize = .zero

    private var currentAsset: PHAsset {
        photosViewer.displayedAsset ?? asset
    }

    private var currentImage: UIImage? {
        fullImage ?? thumbnail
    }

    private var displayName: String {
        if let resource = PHAssetResource.assetResources(for: currentAsset).first {
            return resource.originalFilename
        }
        return currentAsset.localIdentifier
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0.0) {
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
                    // Crossfade to full image when loaded
                    if let fullImage, isFullImageLoaded {
                        Image(uiImage: fullImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 8.0))
                            .transition(.opacity)
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
            .padding(.vertical, 20)
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

            // Carousel strip for navigating between photos
            if photosViewer.allAssets.count > 1 {
                PhotosAssetCarouselStrip()
                    .padding(.horizontal, -20.0)
            }
        }
        .padding(20.0)
        .frame(maxHeight: .infinity)
        .background {
            if let backgroundImage = currentImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 40)
                    .overlay {
                        Color(colorScheme == .dark ? .black : .white)
                            .opacity(0.3)
                    }
                    .ignoresSafeArea()
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let creationDate = currentAsset.creationDate {
                ToolbarItem(placement: .subtitle) {
                    Text(creationDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Shared.Copy", systemImage: "doc.on.doc") {
                    if let image = currentImage {
                        UIPasteboard.general.image = image
                    }
                }
                if let image = currentImage, let cgImage = image.cgImage {
                    ShareLink(
                        "Shared.Share",
                        item: Image(cgImage, scale: image.scale, label: Text("")),
                        preview: SharePreview(
                            displayName,
                            image: Image(uiImage: image)
                        )
                    )
                }
            }
        }
        .task(id: currentAsset.localIdentifier) {
            thumbnail = nil
            fullImage = nil
            isFullImageLoaded = false
            loadThumbnail()
            await loadFullImage()
        }
#if targetEnvironment(macCatalyst)
        .focusable()
        .onKeyPress(.leftArrow) {
            withAnimation(.smooth.speed(2)) {
                photosViewer.navigateToPrevious()
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            withAnimation(.smooth.speed(2)) {
                photosViewer.navigateToNext()
            }
            return .handled
        }
#else
        .gesture(
            MagnifyGesture()
                .onChanged { gesture in
                    if gesture.magnification > 1.0 {
                        magnification = gesture.magnification
                        magnificationAnchor = gesture.startAnchor
                    } else {
                        magnification = 1.0
                    }
                }
                .onEnded { _ in
                    doWithAnimation {
                        magnification = 1.0
                        displayOffset = .zero
                    } completion: {
                        magnificationAnchor = .center
                    }
                }
        )
#endif
    }

    // MARK: - Image Loading

    private func loadThumbnail() {
        let manager = PHCachingImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        let screenSize = UIScreen.main.bounds.size
        let targetSize = CGSize(width: screenSize.width * displayScale,
                                height: screenSize.height * displayScale)

        manager.requestImage(for: currentAsset, targetSize: targetSize,
                             contentMode: .aspectFit, options: options) { result, _ in
            if let result {
                DispatchQueue.main.async {
                    self.thumbnail = result
                }
            }
        }
    }

    private func loadFullImage() async {
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
                        withAnimation(.smooth.speed(2)) {
                            self.fullImage = result
                            self.isFullImageLoaded = true
                        }
                    }
                }
                continuation.resume()
            }
        }
    }
}

// MARK: - Carousel Strip

private struct PhotosAssetCarouselStrip: View {

    @Environment(PhotosViewerManager.self) var photosViewer

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4.0) {
                    ForEach(Array(photosViewer.allAssets.enumerated()),
                            id: \.element.localIdentifier) { index, asset in
                        Button {
                            withAnimation(.smooth.speed(2)) {
                                photosViewer.navigateTo(index: index)
                            }
                        } label: {
                            PhotosCarouselThumbnail(
                                asset: asset,
                                isSelected: index == photosViewer.currentIndex
                            )
                        }
                        .buttonStyle(.plain)
                        .id(asset.localIdentifier)
                    }
                }
                .padding(.horizontal, 20.0)
            }
            .frame(height: 56.0)
            .onChange(of: photosViewer.currentIndex) { _, _ in
                if let asset = photosViewer.displayedAsset {
                    withAnimation(.smooth) {
                        proxy.scrollTo(asset.localIdentifier, anchor: .center)
                    }
                }
            }
            .onAppear {
                if let asset = photosViewer.displayedAsset {
                    proxy.scrollTo(asset.localIdentifier, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Carousel Thumbnail

private struct PhotosCarouselThumbnail: View {

    let asset: PHAsset
    let isSelected: Bool

    @Environment(\.displayScale) private var displayScale

    @State private var thumbnail: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.05))
            .frame(width: 48.0, height: 48.0)
            .overlay {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .clipShape(.rect(cornerRadius: 4.0))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4.0)
                        .stroke(Color.accentColor, lineWidth: 2.0)
                }
            }
            .opacity(isSelected ? 1.0 : 0.6)
            .task(id: asset.localIdentifier) {
                loadThumbnail()
            }
            .onDisappear {
                if let requestID {
                    PHCachingImageManager.default().cancelImageRequest(requestID)
                    self.requestID = nil
                }
                thumbnail = nil
            }
    }

    private func loadThumbnail() {
        let manager = PHCachingImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        let targetSize = CGSize(width: 48.0 * displayScale,
                                height: 48.0 * displayScale)

        requestID = manager.requestImage(for: asset, targetSize: targetSize,
                             contentMode: .aspectFill, options: options) { result, _ in
            if let result {
                DispatchQueue.main.async {
                    self.thumbnail = result
                }
            }
        }
    }
}
