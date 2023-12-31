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
            AlbumCover(cornerRadius: 8.0, shadowSize: 4.0, data: album.coverPhoto)
                .toggledMatchedGeometryEffect(id: "\(album.id).Image", in: namespace)
            VStack(alignment: .leading, spacing: 2.0) {
                Text(album.name)
                    .toggledMatchedGeometryEffect(id: "\(album.id).Title", in: namespace)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(alignment: .center, spacing: 8.0) {
                    HStack(alignment: .center, spacing: 4.0) {
                        Group {
                            Image(systemName: "photo.fill")
                            Text(String(album.illustrationCount()))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    }
                    HStack(alignment: .center, spacing: 4.0) {
                        Group {
                            Image(systemName: "rectangle.stack.fill")
                            Text(String(album.albumCount()))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    }
                }
            }
        }
        .contentShape(.rect)
    }
}
