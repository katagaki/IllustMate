//
//  AlbumCover.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftUI

struct AlbumCover: View {

    var length: CGFloat?
    var album: Album

    var primaryImage: Image?
    var secondaryImage: Image?
    var tertiaryImage: Image?

    init(
        length: CGFloat? = nil,
        album: Album,
        primaryImage: Image? = nil,
        secondaryImage: Image? = nil,
        tertiaryImage: Image? = nil
    ) {
        self.length = length
        self.album = album
        self.primaryImage = primaryImage
        self.secondaryImage = secondaryImage
        self.tertiaryImage = tertiaryImage
    }

    var body: some View {
        ZStack(alignment: .center) {
            GeometryReader { metrics in
                ZStack {
                    RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous)
                        .fill(LinearGradient(gradient: Gradient(colors: [.orange, .yellow]),
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                        .frame(width: metrics.size.width, height: metrics.size.height)
                        .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: metrics.size.height * 0.06)
                    ZStack {
                        if let tertiaryImage {
                            AlbumCoverChildImage(image: tertiaryImage, metrics: metrics)
                                .offset(x: -metrics.size.width * 0.13, y: -metrics.size.height * 0.09)
                                .rotationEffect(.degrees(-10))
                                .shadow(color: .black.opacity(0.35), radius: 4.0, x: -2.0, y: 0.0)
                        }
                        if let secondaryImage {
                            AlbumCoverChildImage(image: secondaryImage, metrics: metrics)
                                .offset(x: 0.0, y: -metrics.size.height * 0.06)
                                .rotationEffect(.degrees(0))
                                .shadow(color: .black.opacity(0.35), radius: 4.0, x: 0.0, y: 4.0)
                        }
                        if let primaryImage {
                            AlbumCoverChildImage(image: primaryImage, metrics: metrics)
                                .offset(x: metrics.size.width * 0.13, y: -metrics.size.height * 0.07)
                                .rotationEffect(.degrees(10))
                                .shadow(color: .black.opacity(0.35), radius: 4.0, x: 2.0, y: 2.0)
                        }
                    }
                    .offset(x: 0, y: -metrics.size.height * 0.1)
                    UnevenRoundedRectangle(topLeadingRadius: 0.0,
                                           bottomLeadingRadius: metrics.size.height * 0.12,
                                           bottomTrailingRadius: metrics.size.height * 0.12,
                                           topTrailingRadius: 0.0,
                                           style: .continuous)
                    .fill(LinearGradient(gradient: Gradient(colors: [.yellow, .orange]),
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .frame(width: metrics.size.width, height: metrics.size.height * 0.53)
                    .overlay {
                        UnevenRoundedRectangle(topLeadingRadius: 0.0,
                                               bottomLeadingRadius: metrics.size.height * 0.10,
                                               bottomTrailingRadius: metrics.size.height * 0.10,
                                               topTrailingRadius: 0.0,
                                               style: .continuous)
                        .stroke(LinearGradient(gradient: Gradient(colors: [.black.opacity(0.5), .black.opacity(0.2)]),
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing),
                                style: .init(lineWidth: CGFloat(0.8), lineCap: .round, lineJoin: .round,
                                             dash: [CGFloat(metrics.size.width * 0.04)]))
                        .frame(width: metrics.size.width * 0.95, height: metrics.size.height * 0.485)
                        .overlay {
                            LinearGradient(gradient: Gradient(colors: [.black.opacity(0.8), .black.opacity(0.3)]),
                                           startPoint: .top,
                                           endPoint: .bottom)
                            .mask {
                                if metrics.size.width >= 70 {
                                    HStack(alignment: .center, spacing: 6.0) {
                                        HStack(alignment: .center, spacing: 4.0) {
                                            Group {
                                                Image(systemName: "photo.fill")
                                                if album.picCount() <= 999 {
                                                    Text(String(album.picCount()))
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(0.6)
                                                } else {
                                                    Text(verbatim: "XD")
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(0.6)
                                                }
                                            }
                                            .font(.caption)
                                        }
                                        HStack(alignment: .center, spacing: 4.0) {
                                            Group {
                                                Image(systemName: "rectangle.stack.fill")
                                                Text(String(album.albumCount()))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.6)
                                            }
                                            .font(.caption)
                                        }
                                    }
                                    .scaleEffect(x: min(100.0, metrics.size.width) / 100.0,
                                                 y: min(100.0, metrics.size.width) / 100.0,
                                                 anchor: .center)
                                }
                            }
                        }
                    }
                    .offset(y: metrics.size.height * 0.47 / 2)
                    .shadow(color: .black.opacity(0.15), radius: 4.0, x: 0.0, y: -metrics.size.height * 0.04)
                }
            }
            .transition(.opacity.animation(.smooth.speed(2)))
        }
        .scaledToFit()
        .frame(width: length, height: length)
    }

    struct AsyncAlbumCover: View {

        var album: Album
        var length: CGFloat?
        var cornerRadius: Double = 6.0
        var shadowSize: Double = 2.0

        @State private var primaryImage: Image?
        @State private var secondaryImage: Image?
        @State private var tertiaryImage: Image?

        var body: some View {
            AlbumCover(length: length,
                       album: album,
                       primaryImage: primaryImage,
                       secondaryImage: secondaryImage,
                       tertiaryImage: tertiaryImage)
            .task(id: album.id) {
                await loadRepresentativePhotos()
            }
        }

        private func loadRepresentativePhotos() async {
            var images: [Image?] = []
            if let coverPhoto = album.coverPhoto, let uiImage = UIImage(data: coverPhoto) {
                images.append(Image(uiImage: uiImage))
            }
            let thumbnails = await dataActor.representativeThumbnails(forAlbumWithID: album.id)
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

    struct AlbumCoverChildImage: View {

        var image: Image
        var metrics: GeometryProxy

        var body: some View {
            image
                .resizable()
                .scaledToFill()
                .frame(width: metrics.size.width * 0.66,
                       height: metrics.size.height * 0.66)
                .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: metrics.size.height * 0.05)
                        .stroke(Color.primary.opacity(0.2), style: .init(lineWidth: CGFloat(0.5)))
                }
        }
    }
}
