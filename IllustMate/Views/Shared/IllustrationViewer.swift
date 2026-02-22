//
//  IllustrationViewer.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct IllustrationViewer: View {

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(ViewerManager.self) var viewer

    var illustration: Illustration

    @State var displayOffset: CGSize = .zero
    @State var magnification: CGFloat = 1.0
    @State var magnificationAnchor: UnitPoint = .center
    @State var containingAlbumName: String?
    @State var showImageSize: Bool = true

    var currentImage: UIImage? {
        viewer.displayedImage ?? viewer.displayedThumbnail
    }

    var body: some View {
        ZStack {
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
                    .opacity(opacityDuringGesture())
            }

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
                    withAnimation(.snappy.speed(2)) {
                        showImageSize.toggle()
                    }
                }

                // Fixed bottom toolbar with Copy/Share
                HStack(alignment: .center, spacing: 16.0) {
                    Button {
                        if let image = currentImage {
                            UIPasteboard.general.image = image
                        }
                    } label: {
                        Label("Shared.Copy", systemImage: "doc.on.doc")
                            .font(.body)
                    }
                    .buttonStyle(.borderless)

                    if let image = currentImage, let cgImage = image.cgImage {
                        ShareLink(item: Image(cgImage, scale: image.scale, label: Text("")),
                                  preview: SharePreview(illustration.name,
                                                        image: Image(uiImage: image))) {
                            Label("Shared.Share", systemImage: "square.and.arrow.up")
                                .font(.body)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .tint(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassEffect(.regular.interactive(), in: .capsule)
                .opacity(opacityDuringGesture())
            }
            .padding(20.0)
        }
        .navigationTitle(illustration.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(alignment: .center, spacing: 2.0) {
                    Text(illustration.name)
                        .font(.headline)
                        .bold()
                        .lineLimit(1)
                    if let containingAlbumName {
                        Text(containingAlbumName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .task {
            if let albumID = illustration.containingAlbumID {
                containingAlbumName = await actor.album(for: albumID)?.name
            }
        }
#if !targetEnvironment(macCatalyst)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    displayOffset = gesture.translation
                }
                .onEnded { gesture in
                    if hypotenuse(gesture.translation) > 100.0 {
                        dismiss()
                    } else {
                        doWithAnimation {
                            magnification = 1.0
                            displayOffset = .zero
                        } completion: {
                            magnificationAnchor = .center
                        }
                    }
                }
        )
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

    func opacityDuringGesture() -> Double {
        1.0 - hypotenuse(displayOffset) / 100.0
    }

    func hypotenuse(_ translation: CGSize) -> Double {
        let width = translation.width
        let height = translation.height
        return sqrt((width * width) + (height * height))
    }
}
