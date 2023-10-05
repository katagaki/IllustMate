//
//  AlbumRow.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/04.
//

import SwiftUI

struct AlbumRow: View {

    var album: Album

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
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
            .frame(width: 48.0, height: 48.0)
            .clipShape(RoundedRectangle(cornerRadius: 6.0))
            .shadow(color: .black.opacity(0.2), radius: 2.0, x: 0.0, y: 2.0)
            VStack(alignment: .leading, spacing: 2.0) {
                Text(album.name)
                    .font(.body)
                Text("Shared.Album.\(album.illustrations().count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
