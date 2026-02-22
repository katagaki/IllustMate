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

    @State private var primaryImage: Image?
    @State private var secondaryImage: Image?
    @State private var tertiaryImage: Image?

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            AlbumCover(length: 48.0,
                       album: album,
                       primaryImage: primaryImage,
                       secondaryImage: secondaryImage,
                       tertiaryImage: tertiaryImage)
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
        .task(id: album.id) {
            await loadRepresentativePhotos()
        }
    }

    private func loadRepresentativePhotos() async {
        var images: [Image?] = []
        if let coverPhoto = album.coverPhoto, let uiImage = UIImage(data: coverPhoto) {
            images.append(Image(uiImage: uiImage))
        }
        let thumbnails = await actor.representativeThumbnails(forAlbumWithID: album.id)
        for thumbData in thumbnails {
            if let uiImage = UIImage(data: thumbData) {
                images.append(Image(uiImage: uiImage))
            }
        }
        while images.count < 3 { images.append(nil) }
        primaryImage = images[0]
        secondaryImage = images[1]
        tertiaryImage = images[2]
    }
}
