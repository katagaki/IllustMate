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

    @AppStorage(wrappedValue: false, "DebugShowAlbumCoverResolution") var showAlbumCoverResolution: Bool

    var body: some View {
        ZStack(alignment: .center) {
            if let data, let coverPhoto = UIImage(data: data) {
                Image(uiImage: coverPhoto)
                    .resizable()
                    .overlay {
                        if showAlbumCoverResolution {
                            Text(verbatim: "\(coverPhoto.size.width)x\(coverPhoto.size.height)")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(2.0)
                                .background(.accent.opacity(0.7))
                                .clipShape(.rect(cornerRadius: 6.0))
                        }
                    }
                    .transition(.opacity.animation(.snappy.speed(2)))
            } else {
                Image("Album.Generic")
                    .resizable()
            }
        }
        .background(.secondary)
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
