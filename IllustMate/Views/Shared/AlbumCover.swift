//
//  AlbumCover.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftUI

struct AlbumCover: View {

    var length: CGFloat?
    var cornerRadius: Double
    var shadowSize: Double
    var album: Album

    var primaryImage: Image?
    var secondaryImage: Image?
    var tertiaryImage: Image?

    init(length: CGFloat? = nil, cornerRadius: Double = 6.0, shadowSize: Double = 2.0,
         album: Album, primaryImage: Image? = nil, secondaryImage: Image? = nil, tertiaryImage: Image? = nil) {
        self.length = length
        self.cornerRadius = cornerRadius
        self.shadowSize = shadowSize
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
                                if metrics.size.width >= 100 {
                                    HStack(alignment: .center, spacing: 8.0) {
                                        HStack(alignment: .center, spacing: 4.0) {
                                            Group {
                                                Image(systemName: "photo.fill")
                                                Text(String(album.illustrationCount()))
                                                    .lineLimit(1)
                                            }
                                            .font(.caption)
                                        }
                                        HStack(alignment: .center, spacing: 4.0) {
                                            Group {
                                                Image(systemName: "rectangle.stack.fill")
                                                Text(String(album.albumCount()))
                                                    .lineLimit(1)
                                            }
                                            .font(.caption)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .offset(y: metrics.size.height * 0.47 / 2)
                    .shadow(color: .black.opacity(0.15), radius: 4.0, x: 0.0, y: -metrics.size.height * 0.04)
                }
            }
            .toggledTransition(.opacity.animation(.snappy.speed(2)))
        }
        .scaledToFit()
        .frame(width: length, height: length)
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
