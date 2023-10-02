//
//  IllustrationViewerView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI

struct IllustrationViewerView: View {

    var illustration: Illustration

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
        .navigationTitle(illustration.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
