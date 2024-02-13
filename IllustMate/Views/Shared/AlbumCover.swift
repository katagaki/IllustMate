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
    var data: Data?

    @State var primaryImage: Image
    @State var secondaryImage: Image
    @State var tertiaryImage: Image

    init(length: CGFloat? = nil, cornerRadius: Double = 6.0, shadowSize: Double = 2.0,
         data: Data? = nil, primaryImage: Image? = nil, secondaryImage: Image? = nil, tertiaryImage: Image? = nil) {
        self.length = length
        self.cornerRadius = cornerRadius
        self.shadowSize = shadowSize
        self.data = data
        if let primaryImage {
            self.primaryImage = primaryImage
        } else {
            self.primaryImage = Image(.albumGeneric)
        }
        if let secondaryImage {
            self.secondaryImage = secondaryImage
        } else {
            self.secondaryImage = Image(.albumGeneric)
        }
        if let tertiaryImage {
            self.tertiaryImage = tertiaryImage
        } else {
            self.tertiaryImage = Image(.albumGeneric)
        }
    }

    var body: some View {
        ZStack(alignment: .center) {
            GeometryReader { metrics in
                ZStack {
                    RoundedRectangle(cornerRadius: metrics.size.height * 0.12, style: .continuous)
                        .fill(LinearGradient(gradient: Gradient(colors: [.orange, .yellow]),
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing
                                            ))
                        .frame(width: metrics.size.width, height: metrics.size.height)
                        .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: metrics.size.height * 0.06)
                    ZStack {
                        AlbumCoverChildImage(image: tertiaryImage, metrics: metrics)
                            .offset(x: -metrics.size.width * 0.13, y: -metrics.size.height * 0.09)
                            .rotationEffect(.degrees(-10))
                            .shadow(color: .black.opacity(0.35), radius: 4.0, x: -2.0, y: 0.0)
                        AlbumCoverChildImage(image: secondaryImage, metrics: metrics)
                            .offset(x: 0.0, y: -metrics.size.height * 0.06)
                            .rotationEffect(.degrees(0))
                            .shadow(color: .black.opacity(0.35), radius: 4.0, x: 0.0, y: 4.0)
                        AlbumCoverChildImage(image: primaryImage, metrics: metrics)
                            .offset(x: metrics.size.width * 0.13, y: -metrics.size.height * 0.07)
                            .rotationEffect(.degrees(10))
                            .shadow(color: .black.opacity(0.35), radius: 4.0, x: 2.0, y: 2.0)
                    }
                    .offset(x: 0, y: -metrics.size.height * 0.1)
                    UnevenRoundedRectangle(topLeadingRadius: 0.0,
                                           bottomLeadingRadius: metrics.size.height * 0.12,
                                           bottomTrailingRadius: metrics.size.height * 0.12,
                                           topTrailingRadius: 0.0,
                                           style: .continuous)
                    .fill(LinearGradient(gradient: Gradient(colors: [.yellow, .orange]),
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing
                                        ))
                    .frame(width: metrics.size.width, height: metrics.size.height * 0.53)
                    .overlay {
                        UnevenRoundedRectangle(topLeadingRadius: 0.0,
                                               bottomLeadingRadius: metrics.size.height * 0.10,
                                               bottomTrailingRadius: metrics.size.height * 0.10,
                                               topTrailingRadius: 0.0,
                                               style: .continuous)
                        .stroke(LinearGradient(gradient: Gradient(colors: [.black.opacity(0.5), .black.opacity(0.2)]),
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing
                                              ),
                                style: .init(lineWidth: CGFloat(0.8), lineCap: .round, lineJoin: .round,
                                             dash: [CGFloat(metrics.size.width * 0.04)]))
                        .frame(width: metrics.size.width * 0.95, height: metrics.size.height * 0.485)
                    }
                    .offset(y: metrics.size.height * 0.47 / 2)
                    .shadow(color: .black.opacity(0.15), radius: 4.0, x: 0.0, y: -metrics.size.height * 0.04)
                }
            }
            .toggledTransition(.opacity.animation(.snappy.speed(2)))
        }
        .scaledToFit()
        .frame(width: length, height: length)
        .onAppear {
            if let data, let coverImage = UIImage(data: data) {
                primaryImage = Image(uiImage: coverImage)
            }
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
