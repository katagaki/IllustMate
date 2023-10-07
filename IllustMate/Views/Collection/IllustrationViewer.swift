//
//  IllustrationViewer.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct IllustrationViewer: View {

    var namespace: Namespace.ID

    @State var displayedIllustration: Illustration
    @Binding var illustrationDisplayOffset: CGSize
    var closeAction: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 16.0) {
            HStack(alignment: .center, spacing: 8.0) {
                Text(displayedIllustration.name)
                    .bold()
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button {
                    closeAction()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24.0, height: 24.0)
                        .foregroundStyle(.primary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            AsyncImage(url: URL(filePath: displayedIllustration.illustrationPath())) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
            } placeholder: {
                Rectangle()
                    .foregroundStyle(.clear)
            }
            .zIndex(1)
            .offset(illustrationDisplayOffset)
            .transition(.opacity.animation(.snappy.speed(2)))
            Spacer(minLength: 0)
            if let image = UIImage(contentsOfFile: displayedIllustration.illustrationPath()) {
                HStack(alignment: .center, spacing: 16.0) {
                    Button("Shared.Copy", systemImage: "doc.on.doc") {
                        UIPasteboard.general.image = image
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(RoundedRectangle(cornerRadius: 99))
                    ShareLink(item: Image(uiImage: image),
                              preview: SharePreview(displayedIllustration.name, image: Image(uiImage: image))) {
                        Label("Shared.Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(RoundedRectangle(cornerRadius: 99))
                }
            }
        }
        .matchedGeometryEffect(id: displayedIllustration.id, in: namespace)
        .padding()
        .background(.regularMaterial)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    illustrationDisplayOffset = gesture.translation
                }
                .onEnded { gesture in
                    let width = gesture.translation.width
                    let height = gesture.translation.height
                    let hypotenuse = sqrt((width * width) + (height * height))
                    if hypotenuse > 50.0 {
                        closeAction()
                    } else {
                        withAnimation(.snappy.speed(2)) {
                            illustrationDisplayOffset = .zero
                        }
                    }
                }
        )
    }
}
