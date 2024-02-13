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
    var representativePhotos: [Image]

    init(namespace: Namespace.ID, album: Album) {
        self.namespace = namespace
        self.album = album
        self.representativePhotos = AlbumGridLabel.representativePhotosFor(album: album)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            AlbumCover(cornerRadius: 8.0, shadowSize: 4.0, data: album.coverPhoto,
                       primaryImage: representativePhotos[0],
                       secondaryImage: representativePhotos[1],
                       tertiaryImage: representativePhotos[2])
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

    static func representativePhotosFor(album: Album) -> [Image] {
        var imagesToReturn: [Image] = []
        let genericImage: Image = Image(uiImage: UIImage(named: "Album.Generic")!)
        if let illustrations = album.childIllustrations {
            let sortedIllustrations = illustrations.sorted { lhs, rhs in
                lhs.dateAdded < rhs.dateAdded
            }
            let primaryImage: Illustration? = sortedIllustrations.count >= 1 ? sortedIllustrations[0] : nil
            let secondaryImage: Illustration? = sortedIllustrations.count >= 2 ? sortedIllustrations[1] : nil
            let tertiaryImage: Illustration? = sortedIllustrations.count >= 3 ? sortedIllustrations[2] : nil
            if let coverPhoto = album.coverPhoto, let coverImage = UIImage(data: coverPhoto) {
                imagesToReturn.append(Image(uiImage: coverImage))
                if let primaryImage, let thumbnail = primaryImage.cachedThumbnail?.image() {
                    imagesToReturn.append(Image(uiImage: thumbnail))
                }
                if let secondaryImage, let thumbnail = secondaryImage.cachedThumbnail?.image() {
                    imagesToReturn.append(Image(uiImage: thumbnail))
                }
            } else {
                if let primaryImage, let thumbnail = primaryImage.cachedThumbnail?.image() {
                    imagesToReturn.append(Image(uiImage: thumbnail))
                }
                if let secondaryImage, let thumbnail = secondaryImage.cachedThumbnail?.image() {
                    imagesToReturn.append(Image(uiImage: thumbnail))
                }
                if let tertiaryImage, let thumbnail = tertiaryImage.cachedThumbnail?.image() {
                    imagesToReturn.append(Image(uiImage: thumbnail))
                }
            }
        }
        if imagesToReturn.count < 3 {
            for _ in imagesToReturn.count...3 {
                imagesToReturn.append(genericImage)
            }
        }
        return imagesToReturn
    }
}
