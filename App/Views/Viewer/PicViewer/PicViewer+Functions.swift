import AVKit
import SwiftUI

extension PicViewer {

    @ViewBuilder
    var mainContent: some View {
        if isLandscape {
            HStack(spacing: 0.0) {
                if viewer.allPics.count > 1 {
                    PicCarouselStripVertical()
                        .padding(.vertical, fitToScreen ? 0.0 : -8.0)
                }
                imageContent
            }
            .padding(fitToScreen ? 0.0 : 8.0)
            .padding(.leading, fitToScreen ? 0.0 : 40.0)
        } else {
            VStack(alignment: .center, spacing: 0.0) {
                imageContent

                if viewer.allPics.count > 1 {
                    PicCarouselStrip()
                        .padding(.top, fitToScreen ? 12.0 : 0.0)
                        .padding(.horizontal, fitToScreen ? 0.0 : -20.0)
                }
            }
            .padding([.top, .horizontal], fitToScreen ? 0.0 : 20.0)
        }
    }

    var imageCornerRadius: CGFloat {
        fitToScreen ? 0.0 : 8.0
    }

    var imageShadowOpacity: CGFloat {
        fitToScreen ? 0.0 : 0.2
    }

    @ViewBuilder
    var imageContent: some View {
        ZStack {
            if swipeOffset > 0.0,
               let previousImage = viewer.previewImage(at: viewer.currentIndex - 1) {
                neighborPreview(previousImage)
                    .offset(x: swipeOffset - swipeSlideDistance)
            }
            if swipeOffset < 0.0,
               let nextImage = viewer.previewImage(at: viewer.currentIndex + 1) {
                neighborPreview(nextImage)
                    .offset(x: swipeOffset + swipeSlideDistance)
            }
            currentContent
                .offset(x: swipeOffset)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            swipeContentWidth = newWidth
        }
        .simultaneousGesture(swipeGesture)
    }

    @ViewBuilder
    var currentContent: some View {
        if viewer.displayedPic?.isVideo == true {
            videoContent
        } else {
            photoContent
        }
    }

    func neighborPreview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(.rect(cornerRadius: imageCornerRadius))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, fitToScreen ? 0.0 : (isLandscape ? 4.0 : 20.0))
            .padding(.bottom, fitToScreen || isLandscape ? 0.0 : 20.0)
            .shadow(color: .black.opacity(imageShadowOpacity), radius: 4.0, x: 0.0, y: 4.0)
    }

    var swipeSlideDistance: CGFloat {
        max(swipeContentWidth, 1.0) + 32.0
    }

    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 15.0)
            .onChanged { value in
                guard magnification == 1.0 else { return }
                if !isSwipeTracking {
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    isSwipeTracking = true
                }
                var offset = value.translation.width
                if (!viewer.hasPrevious && offset > 0.0) || (!viewer.hasNext && offset < 0.0) {
                    offset /= 3.0
                }
                swipeOffset = offset
            }
            .onEnded { value in
                guard isSwipeTracking else { return }
                isSwipeTracking = false
                endSwipe(predictedTranslation: value.predictedEndTranslation.width,
                         velocity: value.velocity.width)
            }
    }

    func endSwipe(predictedTranslation: CGFloat, velocity: CGFloat) {
        let threshold = swipeSlideDistance / 3.0
        if predictedTranslation < -threshold, viewer.hasNext {
            animateSwipe(to: -swipeSlideDistance, velocity: velocity) {
                viewer.navigateToNext()
                swipeOffset = 0.0
            }
        } else if predictedTranslation > threshold, viewer.hasPrevious {
            animateSwipe(to: swipeSlideDistance, velocity: velocity) {
                viewer.navigateToPrevious()
                swipeOffset = 0.0
            }
        } else {
            animateSwipe(to: 0.0, velocity: velocity, completion: nil)
        }
    }

    func animateSwipe(to target: CGFloat, velocity: CGFloat, completion: (() -> Void)?) {
        let distance = target - swipeOffset
        // interpolatingSpring expects initialVelocity normalized as a fraction of the
        // remaining distance per second, so the gesture velocity carries into the animation
        let initialVelocity = abs(distance) > 0.1 ? velocity / distance : 0.0
        withAnimation(.interpolatingSpring(stiffness: 280.0, damping: 30.0,
                                           initialVelocity: initialVelocity)) {
            swipeOffset = target
        } completion: {
            completion?()
        }
    }

    /// Bottom-trailing indicator shared by photo and video content: a progress ring or spinner while
    /// the original is downloading from iCloud, or a tappable error badge if the download failed.
    @ViewBuilder
    var downloadStatusOverlay: some View {
        if viewer.didDisplayedOriginalDownloadFail {
            Button {
                showDownloadFailedPopover = true
            } label: {
                Image(systemName: "exclamationmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .orange)
                    .frame(width: 20.0, height: 20.0)
                    .shadow(color: .black.opacity(0.4), radius: 2.0)
                    .padding(8.0)
            }
            .buttonStyle(.plain)
            .transition(.opacity)
            .popover(isPresented: $showDownloadFailedPopover) {
                VStack(alignment: .leading, spacing: 8.0) {
                    Label("Shared.OriginalUnavailable.Title", systemImage: "exclamationmark.circle")
                        .font(.headline)
                    Text("Shared.OriginalUnavailable.Description")
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 260.0, alignment: .leading)
                .padding()
                .presentationCompactAdaptation(.popover)
            }
        } else if viewer.isDownloadingDisplayedOriginal {
            Group {
                if let progress = viewer.downloadProgress {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.35), lineWidth: 2.5)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .animation(.smooth, value: progress)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }
            .frame(width: 20.0, height: 20.0)
            .shadow(color: .black.opacity(0.4), radius: 2.0)
            .padding(8.0)
            .transition(.opacity)
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
                    VideoPlayerView(player: player)
                        .aspectRatio(videoAspectRatio ?? 16.0 / 9.0, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: imageCornerRadius))
                } else if let thumbnail = viewer.displayedThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: imageCornerRadius))
                }
            }
            .shadow(color: .black.opacity(imageShadowOpacity), radius: 4.0, x: 0.0, y: 4.0)
            .overlay(alignment: .bottomTrailing) {
                downloadStatusOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, fitToScreen ? 0.0 : (isLandscape ? 4.0 : 20.0))
        .padding(.bottom, fitToScreen || isLandscape ? 0.0 : 20.0)
        .zIndex(1)
        .onTapGesture {
            withAnimation(.smooth.speed(2)) {
                showImageSize.toggle()
            }
        }
    }

    var photoContent: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                if let thumbnail = viewer.displayedThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: imageCornerRadius))
                        .opacity(viewer.displayedImage == nil ? 1 : 0)
                }
                if let fullImage = viewer.displayedImage {
                    Image(uiImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: imageCornerRadius))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                downloadStatusOverlay
            }

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
        .padding(.top, fitToScreen ? 0.0 : (isLandscape ? 4.0 : 20.0))
        .padding(.bottom, fitToScreen || isLandscape ? 0.0 : 20.0)
        .shadow(color: .black.opacity(imageShadowOpacity), radius: 4.0, x: 0.0, y: 4.0)
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

    func deleteDisplayedPic() {
        guard let pic = viewer.displayedPic else { return }
        Task {
            await DataActor.shared.deletePic(withID: pic.id)
            await PColorActor.shared.deleteColor(forPicWithID: pic.id)
            if let albumID = pic.containingAlbumID {
                AlbumCoverCache.shared.removeImages(forAlbumID: albumID)
            }
            let collectionID = DataActor.shared.collectionID
            Task.detached {
                await OriginalsManager.shared.deleteCloudOriginals(picIDs: [pic.id], in: collectionID)
            }
            if !viewer.removeDisplayedPicAndShowNeighbor() {
                dismiss()
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
