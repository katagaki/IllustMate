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

    var id: String
    var image: UIImage?
    var title: String
    var numberOfIllustrations: Int
    var numberOfAlbums: Int
    @State var shouldDisplay: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
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
            .frame(width: 48.0, height: 48.0)
            .clipShape(RoundedRectangle(cornerRadius: 6.0))
            .shadow(color: .black.opacity(0.2), radius: 2.0, x: 0.0, y: 2.0)
            VStack(alignment: .leading, spacing: 2.0) {
                Text(title)
                    .matchedGeometryEffect(id: "\(id).Title", in: namespace)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("Albums.Detail.\(numberOfIllustrations),\(numberOfAlbums)")
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
        .contentShape(Rectangle())
        .padding([.leading, .trailing], 20.0)
        .padding([.top, .bottom], 8.0)
        .background(colorScheme == .light ?
                    Color.init(uiColor: .secondarySystemGroupedBackground) :
                        Color.init(uiColor: .systemBackground))
    }
}
