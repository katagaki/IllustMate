//
//  AlbumRow.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/04.
//

import SwiftUI

struct AlbumRow: View {

    var album: Album
    @State var image: UIImage?

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            AlbumCover(length: 48.0, data: album.coverPhoto)
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
