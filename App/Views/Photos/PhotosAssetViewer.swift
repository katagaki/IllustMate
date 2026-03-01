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

    let asset: PHAsset

    @Environment(\.displayScale) private var displayScale

    @State private var thumbnail: UIImage?
    @State private var fullImage: UIImage?
    @State private var isFullImageLoaded: Bool = false
    @State private var showImageSize: Bool = true
    @State private var magnification: CGFloat = 1.0
    @State private var magnificationAnchor: UnitPoint = .center
    @State private var displayOffset: CGSize = .zero

    private var currentImage: UIImage? {
        fullImage ?? thumbnail
    }

    private var displayName: String {
        if let resource = PHAssetResource.assetResources(for: asset).first {
            return resource.originalFilename
        }
        return asset.localIdentifier
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
            if let creationDate = asset.creationDate {
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
        .task {
            loadThumbnail()
            await loadFullImage()
        }
#if !targetEnvironment(macCatalyst)
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

        manager.requestImage(for: asset, targetSize: targetSize,
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

            manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize,
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
