//
//  AlbumCover.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftUI

struct AlbumCover: View {

    var length: Double?
    var cornerRadius: Double = 6.0
    var shadowSize: Double = 2.0
    var data: Data?
    @State var image: UIImage?

    var body: some View {
        Group {
            if let length {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                    } else {
                        Image("Album.Generic")
                            .resizable()
                    }
                }
                .frame(width: length, height: length)
            } else {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                } else {
                    Image("Album.Generic")
                        .resizable()
                }
            }
        }
        .aspectRatio(1.0, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(0.2), radius: shadowSize, x: 0.0, y: shadowSize)
        .task {
            DispatchQueue.global(qos: .userInteractive).async {
                if let data, let coverPhoto = UIImage(data: data) {
                    image = coverPhoto
                }
            }
        }
    }
}
