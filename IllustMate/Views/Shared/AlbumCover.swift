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

    var body: some View {
        ZStack(alignment: .center) {
            Image("Album.Generic")
                .resizable()
            if let data, let coverPhoto = UIImage(data: data) {
                Image(uiImage: coverPhoto)
                    .resizable()
                    .transition(.opacity.animation(.snappy.speed(2)))
            }
        }
        .frame(width: length, height: length)
        .aspectRatio(1.0, contentMode: .fill)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(0.2), radius: shadowSize, x: 0.0, y: shadowSize)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(.secondary, lineWidth: 1/3)
        }
    }
}
