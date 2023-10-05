//
//  IllustrationViewerView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI

struct IllustrationViewerView: View {

    var illustration: Illustration
    @State var image: UIImage?
    @State var name: String = ""
    @State var isInitialLoadCompleted: Bool = false

    var body: some View {
        VStack(alignment: .center, spacing: 8.0) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                if isInitialLoadCompleted {
                    Image(systemName: "xmark.octagon.fill")
                        .symbolRenderingMode(.multicolor)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32.0, height: 32.0)
                    Text("Illustration.Error.CouldNotOpen")
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .task {
            self.image = illustration.image()
            self.name = illustration.name
            isInitialLoadCompleted = true
        }
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
                if let uiImage = image {
                    let image = Image(uiImage: uiImage)
                    ShareLink(item: image, preview: SharePreview(name, image: image)) {
                        Label("Shared.Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .overlay(Rectangle().frame(width: nil,
                                       height: 1/3,
                                       alignment: .top).foregroundColor(.primary.opacity(0.3)),
                     alignment: .top)
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
