//
//  AlbumItem.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import SwiftUI

struct AlbumItem: View {

    var album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Group {
                if let coverPhotoData = album.coverPhoto,
                   let coverPhoto = UIImage(data: coverPhotoData) {
                    Image(uiImage: coverPhoto)
                        .resizable()
                } else {
                    Image("Album.Generic")
                        .resizable()
                }
            }
            .aspectRatio(1.0, contentMode: .fill)
            .foregroundStyle(.accent)
            .background(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8.0))
            .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
            VStack(alignment: .leading, spacing: 2.0) {
                Text(album.name)
                    .tint(.primary)
                Text(String(album.illustrations().count))
                    .tint(.secondary)
            }
        }
    }
}
