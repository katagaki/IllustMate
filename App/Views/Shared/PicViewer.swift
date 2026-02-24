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
        .navigationTitle(pic.name)
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
                            pic.name,
                            image: Image(uiImage: image)
                        )
                    )
                }
            }
        }
        .task {
            if let albumID = pic.containingAlbumID {
                let containingAlbumName = await dataActor.album(for: albumID)?.name
                await MainActor.run {
                    withAnimation(.smooth.speed(2.0)) {
                        self.containingAlbumName = containingAlbumName
                    }
                }
            }
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
}
