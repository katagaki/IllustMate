//
//  PicViewer.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct PicViewer: View {

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(ViewerManager.self) var viewer

    var pic: Pic

    @State var displayOffset: CGSize = .zero
    @State var magnification: CGFloat = 1.0
    @State var magnificationAnchor: UnitPoint = .center
    @State var containingAlbumName: String?
    @State var showImageSize: Bool = true

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
        VStack(alignment: .center, spacing: 0.0) {
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
                    // Crossfade to full image when loaded
                    if let fullImage = viewer.displayedImage, viewer.isFullImageLoaded {
                        Image(uiImage: fullImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 8.0))
                            .transition(.opacity)
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

            // Carousel strip for navigating between pics
            if viewer.allPics.count > 1 {
                PicCarouselStrip()
                    .padding(.horizontal, -20.0)
            }
        }
        .padding(20.0)
        .frame(maxHeight: .infinity)
        .background {
            // Blurred image background
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
                            withAnimation(.smooth.speed(2)) {
                                viewer.navigateTo(index: index)
                            }
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
                        .stroke(Color.accentColor, lineWidth: 2.0)
                }
            }
            .opacity(isSelected ? 1.0 : 0.6)
            .task(id: pic.identifiableString()) {
                if let data = pic.thumbnailData {
                    thumbnail = UIImage(data: data)
                } else if let thumbData = await DataActor.shared.thumbnailData(forPicWithID: pic.id) {
                    thumbnail = UIImage(data: thumbData)
                }
            }
            .onDisappear {
                thumbnail = nil
            }
    }
}
