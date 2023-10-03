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
        .task {
            self.image = illustration.image()
            self.name = illustration.name
            isInitialLoadCompleted = true
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let uiImage = image {
                    let image = Image(uiImage: uiImage)
                    ShareLink(item: image, preview: SharePreview(name, image: image))
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
