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
    @State var isRenamePicPresented: Bool = false
    @State var renamePicText: String = ""
    @State var displayedPicName: String = ""

    var isLandscape: Bool {
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
                Canvas { context, size in
                    context.addFilter(.blur(radius: 40))
                    context.addFilter(.brightness(colorScheme == .dark ? -0.5 : 0.1))
                    let image = Image(uiImage: backgroundImage)
                    // Scale to fill the canvas
                    let imageSize = backgroundImage.size
                    let scaleX = size.width / imageSize.width
                    let scaleY = size.height / imageSize.height
                    let scale = max(scaleX, scaleY)
                    let drawWidth = imageSize.width * scale
                    let drawHeight = imageSize.height * scale
                    let drawRect = CGRect(
                        x: (size.width - drawWidth) / 2,
                        y: (size.height - drawHeight) / 2,
                        width: drawWidth,
                        height: drawHeight
                    )
                    context.draw(image, in: drawRect)
                }
                .ignoresSafeArea()
            }
        }
        .navigationTitle(displayedPicName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("ViewTitle.Pics.Rename", isPresented: $isRenamePicPresented) {
            TextField(displayedPicName, text: $renamePicText)
                .textInputAutocapitalization(.words)
            Button("Shared.Rename") {
                let newName = renamePicText.trimmingCharacters(in: .whitespaces)
                guard !newName.isEmpty, let picID = viewer.displayedPic?.id else { return }
                Task {
                    await DataActor.shared.renamePic(withID: picID, to: newName)
                    viewer.displayedPic?.name = newName
                    if let index = viewer.allPics.firstIndex(where: { $0.id == picID }) {
                        viewer.allPics[index].name = newName
                    }
                    withAnimation(.smooth.speed(2.0)) {
                        displayedPicName = newName
                    }
                }
            }
            Button("Shared.Cancel", role: .cancel) { }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2.0) {
                    Button {
                        renamePicText = displayedPicName
                        isRenamePicPresented = true
                    } label: {
                        Text(displayedPicName)
                            .font(.headline)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                    }
                    .buttonStyle(.plain)
                    if let containingAlbumName {
                        Text(containingAlbumName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            if isLandscape {
                // Landscape: show actions in top trailing bar
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewer.displayedPic?.isVideo == true {
                        if let videoURL = viewer.displayedVideoURL {
                            ShareLink(
                                "Shared.Share",
                                item: videoURL,
                                preview: SharePreview(displayedPicName)
                            )
                        }
                    } else {
                        if pipManager.isPossible {
                            Button("Shared.PictureInPicture", systemImage: "pip.enter") {
                                startPictureInPicture()
                            }
                            .disabled(currentImage == nil)
                        }
                        Button("Shared.Copy", systemImage: "doc.on.doc") {
                            if let image = currentImage {
                                UIPasteboard.general.image = image
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                        }
                        .disabled(currentImage == nil)
                        ShareLink(
                            "Shared.Share",
                            item: shareImage,
                            preview: SharePreview(
                                displayedPicName,
                                image: shareImage
                            )
                        )
                        .disabled(currentImage == nil)
                    }
                }
            } else {
                // Portrait: show actions in bottom bar
                if viewer.displayedPic?.isVideo == true {
                    ToolbarSpacer(.flexible, placement: .bottomBar)
                    ToolbarItemGroup(placement: .bottomBar) {
                        if let videoURL = viewer.displayedVideoURL {
                            ShareLink(
                                "Shared.Share",
                                item: videoURL,
                                preview: SharePreview(displayedPicName)
                            )
                        }
                    }
                } else {
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
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                        }
                        .disabled(currentImage == nil)
                        ShareLink(
                            "Shared.Share",
                            item: shareImage,
                            preview: SharePreview(
                                displayedPicName,
                                image: shareImage
                            )
                        )
                        .disabled(currentImage == nil)
                    }
                }
            }
        }
        .toolbar(isLandscape ? .hidden : .automatic, for: .bottomBar)
        .task(id: viewer.displayedPicID) {
            displayedPicName = viewer.displayedPic?.name ?? pic.name
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
