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
    @State var secondaryImage: Image?
    @State var tertiaryImgae: Image?

    var body: some View {
        ZStack(alignment: .center) {
            if let coverPhoto {
                AlbumFolderCover(image1: coverPhoto, image2: secondaryImage, image3: tertiaryImgae)
                    .toggledTransition(.opacity.animation(.snappy.speed(2)))
            } else {
                Image("Album.Generic")
                    .resizable()
            }
        }
        .scaledToFit()
        .frame(width: length, height: length)
        .onAppear {
            if let data, let coverImage = UIImage(data: data) {
                coverPhoto = Image(uiImage: coverImage)
            }
        }
    }
}
