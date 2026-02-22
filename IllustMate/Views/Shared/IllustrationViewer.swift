//
//  IllustrationViewer.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import Komponents
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
    @State var showImageSize: Bool = false

    var body: some View {
        ZStack {
            // Blurred thumbnail background
            if let thumbnail = viewer.displayedThumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 40)
                    .overlay {
                        Color.black.opacity(colorScheme == .dark ? 0.4 : 0.0)
                        Color.white.opacity(colorScheme == .light ? 0.2 : 0.0)
                    }
                    .ignoresSafeArea()
            }
            VStack(alignment: .center, spacing: 0.0) {
                ZStack(alignment: .bottomLeading) {
                    ZStack {
                        // Show thumbnail as placeholder
                        if let thumbnail = viewer.displayedThumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFit()
                                .opacity(viewer.isFullImageLoaded ? 0 : 1)
                        }
                        // Crossfade to full image when loaded
                        if let fullImage = viewer.displayedImage, viewer.isFullImageLoaded {
                            Image(uiImage: fullImage)
                                .resizable()
                                .scaledToFit()
                                .transition(.opacity)
                        }
                    }
                    .onTapGesture {
                        withAnimation(.snappy.speed(2)) {
                            showImageSize.toggle()
                        }
                    }
                    // Image size overlay
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
                .frame(maxHeight: .infinity)
                .offset(displayOffset)
                .scaleEffect(CGSize(width: magnification, height: magnification),
                             anchor: magnificationAnchor)
            }
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
        .safeAreaInset(edge: .bottom) {
            if let displayedImage = viewer.displayedImage, let cgImage = displayedImage.cgImage {
                HStack(alignment: .center, spacing: 16.0) {
                    Button {
                        UIPasteboard.general.image = displayedImage
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.title3)
                    }
                    ShareLink(item: Image(cgImage, scale: displayedImage.scale, label: Text("")),
                              preview: SharePreview(illustration.name,
                                                    image: Image(uiImage: displayedImage))) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassEffect(.regular.interactive(), in: .capsule)
                .padding(.bottom, 8)
            }
        }
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

    func hypotenuse(_ translation: CGSize) -> Double {
        let width = translation.width
        let height = translation.height
        return sqrt((width * width) + (height * height))
    }
}
