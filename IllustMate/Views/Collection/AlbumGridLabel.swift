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

    @State private var primaryImage: Image?
    @State private var secondaryImage: Image?
    @State private var tertiaryImage: Image?

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            AlbumCover(cornerRadius: 8.0,
                       shadowSize: 4.0,
                       album: album,
                       primaryImage: primaryImage,
                       secondaryImage: secondaryImage,
                       tertiaryImage: tertiaryImage)
            .matchedGeometryEffect(id: "\(album.id).Image", in: namespace)
            Text(album.name)
                .matchedGeometryEffect(id: "\(album.id).Title", in: namespace)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .contentShape(.rect)
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
