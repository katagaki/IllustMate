//
//  IllustrationViewer.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct IllustrationViewer: View {

    @Environment(ConcurrencyManager.self) var concurrency

    var namespace: Namespace.ID

    var illustration: Illustration
    var displayedImage: UIImage

    @State var illustrationDisplayOffset: CGSize = .zero

    var closeAction: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 16.0) {
            HStack(alignment: .center, spacing: 8.0) {
                Text(illustration.name)
                    .bold()
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    closeAction()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28.0, height: 28.0)
                        .foregroundStyle(.primary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .opacity(opacityDuringGesture())
            Spacer(minLength: 0)
            Image(uiImage: displayedImage)
                .resizable()
                .scaledToFit()
                .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
                .transition(.opacity.animation(.snappy.speed(2)))
                .zIndex(1)
                .matchedGeometryEffect(id: illustration.id, in: namespace)
                .offset(illustrationDisplayOffset)
            HStack(alignment: .center, spacing: 2.0) {
                Group {
                    Text(verbatim: "\(Int(displayedImage.size.width * displayedImage.scale))")
                    Text(verbatim: "×")
                    Text(verbatim: "\(Int(displayedImage.size.height * displayedImage.scale))")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .opacity(opacityDuringGesture())
            Spacer(minLength: 0)
            if let cgImage = displayedImage.cgImage {
                HStack(alignment: .center, spacing: 16.0) {
                    Button("Shared.Copy", systemImage: "doc.on.doc") {
                        UIPasteboard.general.image = displayedImage
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    ShareLink(item: Image(cgImage, scale: displayedImage.scale, label: Text("")),
                              preview: SharePreview(illustration.name, image: Image(uiImage: displayedImage))) {
                        Label("Shared.Share", systemImage: "square.and.arrow.up")
                    }
                              .buttonStyle(.borderedProminent)
                              .buttonBorderShape(.capsule)
                }
                .opacity(opacityDuringGesture())
            }
        }
        .padding(20.0)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial.opacity(opacityDuringGesture()))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    illustrationDisplayOffset = gesture.translation
                }
                .onEnded { gesture in
                    if hypotenuse(gesture.translation) > 100.0 {
                        closeAction()
                    }
                }
        )
    }

    func opacityDuringGesture() -> Double {
        1.0 - hypotenuse(illustrationDisplayOffset) / 100.0
    }

    func hypotenuse(_ translation: CGSize) -> Double {
        let width = translation.width
        let height = translation.height
        return sqrt((width * width) + (height * height))
    }
}
