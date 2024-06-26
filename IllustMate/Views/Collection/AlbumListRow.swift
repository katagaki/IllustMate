//
//  AlbumListRow.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct AlbumListRow: View {

    @Environment(\.colorScheme) var colorScheme

    var namespace: Namespace.ID

    var album: Album
    var representativePhotos: [Image?]

    init(namespace: Namespace.ID, album: Album) {
        self.namespace = namespace
        self.album = album
        self.representativePhotos = album.representativePhotos()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            AlbumCover(length: 48.0,
                       album: album,
                       primaryImage: representativePhotos[0],
                       secondaryImage: representativePhotos[1],
                       tertiaryImage: representativePhotos[2])
                .matchedGeometryEffect(id: "\(album.id).Image", in: namespace)
            VStack(alignment: .leading, spacing: 2.0) {
                Text(album.name)
                    .matchedGeometryEffect(id: "\(album.id).Title", in: namespace)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("Albums.Detail.\(album.illustrationCount()),\(album.albumCount())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .resizable()
                .scaledToFit()
                .frame(width: 11.0, height: 11.0)
                .foregroundStyle(.primary.opacity(0.25))
                .fontWeight(.bold)
        }
        .contentShape(.rect)
        .padding([.leading, .trailing], 20.0)
        .padding([.top, .bottom], 8.0)
        .background(colorScheme == .light ?
                    Color.init(uiColor: .secondarySystemGroupedBackground) :
                        Color.init(uiColor: .systemBackground))
    }
}
