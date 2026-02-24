//
//  AlbumGridLabel.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct AlbumGridLabel: View {

    var namespace: Namespace.ID
    var album: Album
    var length: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            AlbumCover.AsyncAlbumCover(album: album, length: length)
            .matchedGeometryEffect(id: "\(album.id).Image", in: namespace)
            Text(album.name)
                .matchedGeometryEffect(id: "\(album.id).Title", in: namespace)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .contentShape(.rect)
        .frame(width: length)
    }
}
