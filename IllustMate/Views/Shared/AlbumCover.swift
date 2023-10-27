//
//  AlbumCover.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftUI

struct AlbumCover: View {

    var length: CGFloat?
    var cornerRadius: Double = 6.0
    var shadowSize: Double = 2.0
    var data: Data?

    @State var coverPhoto: Image?

    var body: some View {
        ZStack(alignment: .center) {
            if let coverPhoto {
                coverPhoto
                    .resizable()
                    .transitionRespectingAnimationSetting(.opacity.animation(.snappy.speed(2)))
            } else {
                Image("Album.Generic")
                    .resizable()
            }
        }
        .background(.secondary)
        .scaledToFill()
        .frame(width: length, height: length)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(0.2), radius: shadowSize, x: 0.0, y: shadowSize)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(.tertiary, lineWidth: 1/3)
        }
        .onAppear {
            if let data, let coverImage = UIImage(data: data) {
                coverPhoto = Image(uiImage: coverImage)
            }
        }
    }
}
