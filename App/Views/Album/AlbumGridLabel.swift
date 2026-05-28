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
        VStack(alignment: .center, spacing: length == nil ? 2.0 : 6.0) {
            AlbumCover.AsyncAlbumCover(album: album, length: length)
            .matchedGeometryEffect(id: "\(album.id).Image", in: namespace)
            .overlay {
                if let progress = OfflineDownloadProgress.shared.fraction(for: album.id) {
                    ZStack {
                        Circle()
                            .fill(.thinMaterial)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(.tint, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .padding(7)
                    }
                    .frame(width: 40, height: 40)
                    .animation(.smooth, value: progress)
                }
            }
            Text(album.name)
                .matchedGeometryEffect(id: "\(album.id).Title", in: namespace)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 1.0)
                .padding(.bottom, 1.0)
        }
        .contentShape(.rect)
        .frame(width: length)
    }
}
