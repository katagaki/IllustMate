//
//  PicViewer+Functions.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import AVKit
import SwiftUI

extension PicViewer {

    @ViewBuilder
    var mainContent: some View {
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

    @ViewBuilder
    var imageContent: some View {
        if viewer.displayedPic?.isVideo == true {
            videoContent
        } else {
            photoContent
        }
    }

    var videoAspectRatio: CGFloat? {
        guard let thumbnail = viewer.displayedThumbnail,
              thumbnail.size.height > 0 else { return nil }
        return thumbnail.size.width / thumbnail.size.height
    }

    var videoContent: some View {
        VStack(spacing: 8.0) {
            Group {
                if let player = viewer.videoPlayer {
                    VideoPlayer(player: player)
                        .aspectRatio(videoAspectRatio ?? 16.0 / 9.0, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 8.0))
                } else if let thumbnail = viewer.displayedThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 8.0))
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)

            if showImageSize, let duration = viewer.displayedPic?.duration {
                HStack(alignment: .center, spacing: 4.0) {
                    if let res = videoResolution {
                        Text(verbatim: "\(Int(res.width))×\(Int(res.height))")
                        Text(verbatim: "·")
                    }
                    Text(formatDuration(duration))
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.bar, in: .capsule)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, isLandscape ? 4 : 20)
        .padding(.bottom, isLandscape ? 0 : 20)
        .zIndex(1)
        .onTapGesture {
            withAnimation(.smooth.speed(2)) {
                showImageSize.toggle()
            }
        }
    }

    var photoContent: some View {
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

    func startPictureInPicture() {
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
