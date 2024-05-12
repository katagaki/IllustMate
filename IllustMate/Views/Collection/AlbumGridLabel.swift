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
    var representativePhotos: [Image?]

    init(namespace: Namespace.ID, album: Album) {
        self.namespace = namespace
        self.album = album
        self.representativePhotos = album.representativePhotos()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            AlbumCover(cornerRadius: 8.0,
                       shadowSize: 4.0,
                       album: album,
                       primaryImage: representativePhotos[0],
                       secondaryImage: representativePhotos[1],
                       tertiaryImage: representativePhotos[2])
            .toggledMatchedGeometryEffect(id: "\(album.id).Image", in: namespace)
            Text(album.name)
                .toggledMatchedGeometryEffect(id: "\(album.id).Title", in: namespace)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .contentShape(.rect)
    }
}
