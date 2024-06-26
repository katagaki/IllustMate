//
//  IllustrationViewer.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct IllustrationViewer: View {

    @Environment(\.dismiss) var dismiss

    var illustration: Illustration
    var displayedImage: UIImage

    @State var displayOffset: CGSize = .zero
    @State var magnification: CGFloat = 1.0
    @State var magnificationAnchor: UnitPoint = .center

    var body: some View {
        VStack(alignment: .center, spacing: 0.0) {
            Spacer(minLength: 20)
            Image(uiImage: displayedImage)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: 8.0))
                .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
                .zIndex(1)
                .offset(displayOffset)
                .scaleEffect(CGSize(width: magnification, height: magnification), anchor: magnificationAnchor)
            Spacer(minLength: 20)
            if let cgImage = displayedImage.cgImage {
                HStack(alignment: .center, spacing: 16.0) {
                    HStack(alignment: .center, spacing: 2.0) {
                        Group {
                            Text(verbatim: "\(Int(displayedImage.size.width * displayedImage.scale))")
                            Text(verbatim: "×")
                            Text(verbatim: "\(Int(displayedImage.size.height * displayedImage.scale))")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    ShareLink(item: Image(cgImage, scale: displayedImage.scale, label: Text("")),
                              preview: SharePreview(illustration.name, image: Image(uiImage: displayedImage))) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24.0))
                    }
                              .buttonStyle(.borderless)
                              .buttonBorderShape(.capsule)
                }
                .opacity(opacityDuringGesture())
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
                    if let containingAlbum = illustration.containingAlbum {
                        Text(containingAlbum.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(20.0)
        .frame(maxHeight: .infinity)
#if !targetEnvironment(macCatalyst)
        .overlayBackground(opacity: opacityDuringGesture())
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
