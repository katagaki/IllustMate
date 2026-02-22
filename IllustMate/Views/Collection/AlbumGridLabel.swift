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

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            AlbumCover.AsyncAlbumCover(album: album,
                                       cornerRadius: 8.0,
                                       shadowSize: 4.0)
            .matchedGeometryEffect(id: "\(album.id).Image", in: namespace)
            Text(album.name)
                .matchedGeometryEffect(id: "\(album.id).Title", in: namespace)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .contentShape(.rect)
    }
}
