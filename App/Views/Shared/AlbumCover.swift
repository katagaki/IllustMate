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
                ZStack(alignment: .center) {
                    // Stack
                    if let tertiaryImage {
                        tertiaryImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: metrics.size.width * 0.92, height: metrics.size.height * 0.92)
                            .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous))
                            .rotationEffect(.degrees(-12.0))
                            .shadow(color: .black.opacity(0.15), radius: 2.0, x: 0.0, y: metrics.size.height * 0.01)
                            .padding(metrics.size.width * 0.04)
                    }
                    if let secondaryImage {
                        secondaryImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: metrics.size.width * 0.92, height: metrics.size.height * 0.92)
                            .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous))
                            .rotationEffect(.degrees(10.0))
                            .shadow(color: .black.opacity(0.15), radius: 3.0, x: 0.0, y: metrics.size.height * 0.02)
                            .padding(metrics.size.width * 0.04)
                    }

                    if let primaryImage {
                        ZStack(alignment: .bottom) {
                            primaryImage
                                .resizable()
                                .scaledToFill()

                            if metrics.size.width >= 80 {
                                // Variable blur
                                Group {
                                    ForEach(1...5, id: \.self) { index in
                                        primaryImage
                                            .resizable()
                                            .scaledToFill()
                                            .blur(radius: CGFloat(index * index) * 0.8)
                                            .mask {
                                                LinearGradient(
                                                    stops: [
                                                        .init(color: .clear, location: 0.5 + Double(index - 1) * 0.1),
                                                        .init(color: .black, location: 1.0)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            }
                                    }
                                }
                                // Gradient to darken background
                                LinearGradient(colors: [.clear, .black.opacity(0.65)],
                                               startPoint: .center,
                                               endPoint: .bottom)
                            }
                        }
                        .frame(width: metrics.size.width * 0.92, height: metrics.size.height * 0.92)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.35), radius: 4.0, x: 0.0, y: metrics.size.height * 0.03)
                        .padding(metrics.size.width * 0.04)
                    } else {
                        // Use color for empty albums
                        let colors = Color.gradient(from: album.name)
                        RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous)
                            .fill(LinearGradient(colors: [colors.primary, colors.secondary],
                                                 startPoint: .topLeading,
                                                 endPoint: .bottomTrailing))
                            .frame(width: metrics.size.width * 0.92, height: metrics.size.height * 0.92)
                            .shadow(color: .black.opacity(0.35), radius: 4.0, x: 0.0, y: metrics.size.height * 0.03)
                            .padding(metrics.size.width * 0.04)
                    }
                }
                .overlay(alignment: .bottom) {
                    if metrics.size.width >= 80 {
                        AlbumItemCount(of: album)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5),
                                    radius: 2.0,
                                    x: 0.0, y: 1.0)
                            .padding(.bottom, metrics.size.height * 0.1)
                            .allowsHitTesting(false)
                    }
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

        @State private var primaryImage: Image?
        @State private var secondaryImage: Image?
        @State private var tertiaryImage: Image?

        var body: some View {
            AlbumCover(length: length,
                       album: album,
                       primaryImage: primaryImage,
                       secondaryImage: secondaryImage,
                       tertiaryImage: tertiaryImage)
            .task(id: album.identifiableString()) {
                await loadRepresentativePhotos()
            }
        }

        private func loadRepresentativePhotos() async {
            var images: [Image?] = []
            if let coverPhoto = album.coverPhoto, let uiImage = UIImage(data: coverPhoto) {
                images.append(Image(uiImage: uiImage))
            }
            let thumbnails = await DataActor.shared.representativeThumbnails(forAlbumWithID: album.id)
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

struct AlbumItemCount: View {

    let picCount: Int
    let albumCount: Int

    init(of album: Album) {
        self.picCount = album.picCount()
        self.albumCount = album.albumCount()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 6.0) {
            if picCount > 0 || albumCount > 0 {
                if picCount > 0 {
                    iconAndLabel(picCount, systemImage: "photo.fill")
                }
                if albumCount > 0 {
                    iconAndLabel(albumCount, systemImage: "rectangle.stack.fill")
                }
            } else {
                iconAndLabel(0, systemImage: "photo.fill")
                iconAndLabel(0, systemImage: "rectangle.stack.fill")
            }
        }
        .font(.system(size: 10.0, weight: .semibold, design: .rounded))
    }

    func iconAndLabel(_ count: Int, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 2.0) {
            Image(systemName: systemImage)
            Text(String(count))
        }
    }
}
