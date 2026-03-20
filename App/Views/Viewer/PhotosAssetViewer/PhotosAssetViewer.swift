//
//  PhotosAssetViewer.swift
//  PicMate
//
//  Created on 2026/02/28.
//

import AVKit
import Photos
import SwiftUI

struct PhotosAssetViewer: View {

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(PhotosViewerManager.self) var photosViewer
    @EnvironmentObject var navigation: NavigationManager
    @Environment(PictureInPictureManager.self) var pipManager

    let asset: PHAsset

    @Environment(\.displayScale) var displayScale

    @State var thumbnail: UIImage?
    @State var fullImage: UIImage?
    @State var isFullImageLoaded: Bool = false
    @State var showImageSize: Bool = true
    @State var magnification: CGFloat = 1.0
    @State var magnificationAnchor: UnitPoint = .center
    @State var displayOffset: CGSize = .zero
    @State var viewSize: CGSize = .zero

    var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var currentAsset: PHAsset {
        photosViewer.displayedAsset ?? asset
    }

    var currentImage: UIImage? {
        fullImage ?? thumbnail
    }

    var shareImage: Image {
        if let image = currentImage, let cgImage = image.cgImage {
            Image(cgImage, scale: image.scale, label: Text(""))
        } else {
            Image(uiImage: UIImage())
        }
    }

    var displayName: String {
        if let resource = PHAssetResource.assetResources(for: currentAsset).first {
            return resource.originalFilename
        }
        return currentAsset.localIdentifier
    }

    var body: some View {
        mainContent
        .frame(maxHeight: .infinity)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            viewSize = newSize
        }
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
            if isLandscape {
                // Landscape: show actions in top trailing bar
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if pipManager.isPossible {
                        Button("Shared.PictureInPicture", systemImage: "pip.enter") {
                            startPictureInPicture()
                        }
                        .disabled(currentImage == nil)
                    }
                    Button("Shared.Copy", systemImage: "doc.on.doc") {
                        if let image = currentImage {
                            UIPasteboard.general.image = image
                        }
                    }
                    .disabled(currentImage == nil)
                    ShareLink(
                        "Shared.Share",
                        item: shareImage,
                        preview: SharePreview(
                            displayName,
                            image: shareImage
                        )
                    )
                    .disabled(currentImage == nil)
                }
            } else {
                // Portrait: show actions in bottom bar
                if pipManager.isPossible {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Shared.PictureInPicture", systemImage: "pip.enter") {
                            startPictureInPicture()
                        }
                        .disabled(currentImage == nil)
                    }
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Shared.Copy", systemImage: "doc.on.doc") {
                        if let image = currentImage {
                            UIPasteboard.general.image = image
                        }
                    }
                    .disabled(currentImage == nil)
                    ShareLink(
                        "Shared.Share",
                        item: shareImage,
                        preview: SharePreview(
                            displayName,
                            image: shareImage
                        )
                    )
                    .disabled(currentImage == nil)
                }
            }
        }
        .toolbar(isLandscape ? .hidden : .automatic, for: .bottomBar)
        .task(id: currentAsset.localIdentifier) {
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
}
