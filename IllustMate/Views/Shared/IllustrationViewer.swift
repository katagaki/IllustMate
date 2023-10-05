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
    }
}
