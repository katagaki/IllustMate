//
//  PicViewer.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import AVKit
import SwiftUI

struct PicViewer: View {

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(ViewerManager.self) var viewer
    @EnvironmentObject var navigation: NavigationManager
    @Environment(PictureInPictureManager.self) var pipManager

    var pic: Pic

    @State var displayOffset: CGSize = .zero
    @State var magnification: CGFloat = 1.0
    @State var magnificationAnchor: UnitPoint = .center
    @State var containingAlbumName: String?
    @State var showImageSize: Bool = true

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var currentImage: UIImage? {
        viewer.displayedImage ?? viewer.displayedThumbnail
    }

    var shareImage: Image {
        if let image = currentImage, let cgImage = image.cgImage {
            Image(cgImage, scale: image.scale, label: Text(""))
        } else {
            Image(uiImage: UIImage())
        }
    }

    var body: some View {
        mainContent
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
        .navigationTitle(viewer.displayedPic?.name ?? pic.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let containingAlbumName {
                ToolbarItem(placement: .subtitle) {
                    Text(containingAlbumName)
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
                            viewer.displayedPic?.name ?? pic.name,
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
                            viewer.displayedPic?.name ?? pic.name,
                            image: shareImage
                        )
                    )
                    .disabled(currentImage == nil)
                }
            }
        }
        .toolbar(isLandscape ? .hidden : .automatic, for: .bottomBar)
        .task(id: viewer.displayedPicID) {
            containingAlbumName = nil
            if let albumID = viewer.displayedPic?.containingAlbumID ?? pic.containingAlbumID {
                let name = await DataActor.shared.album(for: albumID)?.name
                await MainActor.run {
                    withAnimation(.smooth.speed(2.0)) {
                        self.containingAlbumName = name
                    }
                }
            }
        }
#if targetEnvironment(macCatalyst)
        .focusable()
        .onKeyPress(.leftArrow) {
            viewer.navigateToPrevious()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewer.navigateToNext()
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

    private var imageContent: some View {
        // Image with size overlay - fills available space
        ZStack(alignment: .bottomLeading) {
            ZStack {
                // Show thumbnail as placeholder
                if let thumbnail = viewer.displayedThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 8.0))
                        .opacity(viewer.isFullImageLoaded ? 0 : 1)
                }
                // Show full image when loaded
                if let fullImage = viewer.displayedImage, viewer.isFullImageLoaded {
                    Image(uiImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 8.0))
                }
            }

            // Image size overlay (bottom-left of image)
            if showImageSize, let displayedImage = viewer.displayedImage {
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

    @ViewBuilder
    private var mainContent: some View {
        if isLandscape {
            // Landscape: vertical carousel on the left, image fills remaining space
            HStack(spacing: 0.0) {
                if viewer.allPics.count > 1 {
                    PicCarouselStripVertical()
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

                if viewer.allPics.count > 1 {
                    PicCarouselStrip()
                        .padding(.horizontal, -20.0)
                }
            }
            .padding([.top, .horizontal], 20.0)
        }
    }

    private func startPictureInPicture() {
        guard let image = currentImage else { return }

        let picToRestore = viewer.displayedPic
        let picsToRestore = viewer.allPics
        let indexToRestore = viewer.currentIndex

        pipManager.start(with: image) { [viewer] in
            if let pic = picToRestore {
                viewer.allPics = picsToRestore
                viewer.currentIndex = indexToRestore
                viewer.setDisplay(pic) {}
            }
        }
    }
}

// MARK: - Carousel Strip

private struct PicCarouselStrip: View {

    @Environment(ViewerManager.self) var viewer

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4.0) {
                    ForEach(Array(viewer.allPics.enumerated()), id: \.element.id) { index, pic in
                        Button {
                            viewer.navigateTo(index: index)
                        } label: {
                            CarouselThumbnail(pic: pic, isSelected: index == viewer.currentIndex)
                        }
                        .buttonStyle(.plain)
                        .id(pic.id)
                    }
                }
                .padding(.horizontal, 20.0)
            }
            .frame(height: 56.0)
            .onChange(of: viewer.currentIndex) { _, _ in
                if let pic = viewer.displayedPic {
                    withAnimation(.smooth) {
                        proxy.scrollTo(pic.id, anchor: .center)
                    }
                }
            }
            .onAppear {
                if let pic = viewer.displayedPic {
                    proxy.scrollTo(pic.id, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Vertical Carousel Strip (Landscape)

private struct PicCarouselStripVertical: View {

    @Environment(ViewerManager.self) var viewer

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4.0) {
                    ForEach(Array(viewer.allPics.enumerated()), id: \.element.id) { index, pic in
                        Button {
                            viewer.navigateTo(index: index)
                        } label: {
                            CarouselThumbnail(pic: pic, isSelected: index == viewer.currentIndex)
                        }
                        .buttonStyle(.plain)
                        .id(pic.id)
                    }
                }
                .padding(.vertical, 8.0)
            }
            .frame(width: 56.0)
            .onChange(of: viewer.currentIndex) { _, _ in
                if let pic = viewer.displayedPic {
                    withAnimation(.smooth) {
                        proxy.scrollTo(pic.id, anchor: .center)
                    }
                }
            }
            .onAppear {
                if let pic = viewer.displayedPic {
                    proxy.scrollTo(pic.id, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Carousel Thumbnail

private struct CarouselThumbnail: View {

    let pic: Pic
    let isSelected: Bool

    @State private var thumbnail: UIImage?

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
                        .stroke(.accent, lineWidth: 2.0)
                }
            }
            .opacity(isSelected ? 1.0 : 0.6)
            .animation(.smooth.speed(2), value: isSelected)
            .task(id: pic.identifiableString()) {
                let picID = pic.id
                // Check in-memory cache first
                if let cached = ThumbnailCache.shared.image(forKey: picID) {
                    thumbnail = cached
                    return
                }
                // Try pic's in-memory data, else fetch from DB
                let thumbData: Data?
                if let data = pic.thumbnailData {
                    thumbData = data
                } else {
                    thumbData = await DataActor.shared.thumbnailData(forPicWithID: picID)
                }
                if let thumbData, let uiImage = UIImage(data: thumbData),
                   let prepared = await uiImage.byPreparingForDisplay() {
                    guard !Task.isCancelled else { return }
                    ThumbnailCache.shared.setImage(prepared, forKey: picID)
                    thumbnail = prepared
                }
            }
    }
}
