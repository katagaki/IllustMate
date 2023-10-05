//
//  IllustrationViewerView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftUI

struct IllustrationViewer: View {

    @Namespace var illustrationTransitionNamespace

    @State var illustration: Illustration
    @State var isInitialLoadCompleted: Bool = false

    var body: some View {
        VStack(alignment: .center, spacing: 8.0) {
            if let image = illustration.image() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "xmark.octagon.fill")
                    .symbolRenderingMode(.multicolor)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32.0, height: 32.0)
                Text("Illustration.Error.CouldNotOpen")
            }
        }
        .frame(maxHeight: .infinity)
        .padding()
        .safeAreaInset(edge: .bottom, spacing: 0.0) {
            HStack(alignment: .center, spacing: 16.0) {
                Button {
                    if let image = illustration.image() {
                        UIPasteboard.general.image = image
                    }
                } label: {
                    Label("Shared.Copy", systemImage: "doc.on.doc")
                }
                Spacer()
                if let uiImage = illustration.image() {
                    let image = Image(uiImage: uiImage)
                    ShareLink(item: image, preview: SharePreview(illustration.name, image: image)) {
                        Label("Shared.Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 99))
            .padding()
        }
        .background(.regularMaterial)
    }
}
