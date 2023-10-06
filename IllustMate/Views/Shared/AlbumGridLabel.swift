//
//  AlbumGridLabel.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct AlbumGridLabel: View {

    var namespace: Namespace.ID

    let id: String
    let image: UIImage?
    let title: String
    let numberOfIllustrations: Int
    let numberOfAlbums: Int
    @State var shouldDisplay: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Group {
                if shouldDisplay {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                    } else {
                        Image("Album.Generic")
                            .resizable()
                    }
                } else {
                    Image("Album.Generic")
                        .resizable()
                }
            }
            .matchedGeometryEffect(id: "\(id).Image", in: namespace)
            .aspectRatio(1.0, contentMode: .fill)
            .foregroundStyle(.accent)
            .clipShape(RoundedRectangle(cornerRadius: 8.0))
            .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
            VStack(alignment: .leading, spacing: 2.0) {
                Text(title)
                    .matchedGeometryEffect(id: "\(id).Title", in: namespace)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(alignment: .center, spacing: 8.0) {
                    HStack(alignment: .center, spacing: 4.0) {
                        Group {
                            Image(systemName: "photo.fill")
                            Text(String(numberOfIllustrations))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    }
                    HStack(alignment: .center, spacing: 4.0) {
                        Group {
                            Image(systemName: "rectangle.stack.fill")
                            Text(String(numberOfAlbums))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onAppear {
            shouldDisplay = true
        }
        .onDisappear {
            shouldDisplay = false
        }
    }
}
