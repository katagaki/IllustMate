//
//  AlbumCover.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftUI

struct AlbumCover: View {

    @Environment(ConcurrencyManager.self) var concurrency

    var length: CGFloat?
    var cornerRadius: Double = 6.0
    var shadowSize: Double = 2.0
    var data: Data?
    @State var image: Image?

    var body: some View {
        ZStack(alignment: .center) {
            if let image {
                image
                    .resizable()
                    .transition(.opacity.animation(.snappy.speed(2)))
            } else {
                Image("Album.Generic")
                    .resizable()
            }
        }
        .frame(width: length, height: length)
        .aspectRatio(1.0, contentMode: .fill)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(0.2), radius: shadowSize, x: 0.0, y: shadowSize)
        .task {
            concurrency.queue.addOperation {
                if let data, let coverPhoto = UIImage(data: data) {
                    image = Image(uiImage: coverPhoto)
                }
            }
        }
    }
}
