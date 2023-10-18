//
//  IllustrationLabel.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct IllustrationLabel: View {

    var namespace: Namespace.ID

    var illustration: Illustration
    var isHiddenAndOverridesState: Bool

    var body: some View {
        ZStack(alignment: .center) {
            Color.clear
            if !isHiddenAndOverridesState {
                Group {
                    if let image = illustration.thumbnail() {
                        Image(uiImage: image)
                            .resizable()
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24.0, height: 24.0)
                            .foregroundStyle(.primary)
                            .symbolRenderingMode(.multicolor)
                    }
                }
                .matchedGeometryEffect(id: illustration.id, in: namespace)
            }
        }
        .background(.primary.opacity(0.05))
        .aspectRatio(1.0, contentMode: .fill)
        .contentShape(.rect)
    }
}
