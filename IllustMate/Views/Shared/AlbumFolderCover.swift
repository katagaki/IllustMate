//
//  AlbumFolderCover.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2024/02/13.
//

import SwiftUI

struct AlbumFolderCover: View {

    @State var image1: Image
    @State var image2: Image
    @State var image3: Image

    init(image1: Image?, image2: Image?, image3: Image?) {
        if let image1 {
            self.image1 = image1
        } else {
            self.image1 = Image(.albumGeneric)
        }
        if let image2 {
            self.image2 = image2
        } else {
            self.image2 = Image(.albumGeneric)
        }
        if let image3 {
            self.image3 = image3
        } else {
            self.image3 = Image(.albumGeneric)
        }
    }

    var body: some View {
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
                    image3
                        .resizable()
                        .scaledToFit()
                        .frame(width: metrics.size.width * 0.66,
                               height: metrics.size.height * 0.66)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.05))
                        .offset(x: -metrics.size.width * 0.13, y: -metrics.size.height * 0.09)
                        .rotationEffect(.degrees(-10))
                    image2
                        .resizable()
                        .scaledToFit()
                        .frame(width: metrics.size.width * 0.66,
                               height: metrics.size.height * 0.66)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.05))
                        .offset(x: 0.0, y: -metrics.size.height * 0.06)
                        .rotationEffect(.degrees(0))
                        .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
                    image1
                        .resizable()
                        .scaledToFit()
                        .frame(width: metrics.size.width * 0.66,
                               height: metrics.size.height * 0.66)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.size.height * 0.05))
                        .offset(x: metrics.size.width * 0.13, y: -metrics.size.height * 0.07)
                        .rotationEffect(.degrees(10))
                        .shadow(color: .black.opacity(0.2), radius: 4.0, x: 2.0, y: 2.0)
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
                            style: .init(lineWidth: CGFloat(0.8), lineCap: .round, lineJoin: .round, dash: [CGFloat(metrics.size.width * 0.04)]))
                    .frame(width: metrics.size.width * 0.95, height: metrics.size.height * 0.485)
                }
                .offset(y: metrics.size.height * 0.47 / 2)
                .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: -metrics.size.height * 0.04)
            }
        }
    }
}

#Preview {
    List {
        HStack {
            AlbumFolderCover(image1: Image(.albumGeneric),
                             image2: Image(.albumGeneric),
                             image3: Image(.albumGeneric))
            .frame(width: 50, height: 50, alignment: .center)
            Text("Album Name")
        }
        HStack {
            AlbumFolderCover(image1: Image(.albumGeneric),
                             image2: Image(.albumGeneric),
                             image3: Image(.albumGeneric))
            .frame(width: 100, height: 100, alignment: .center)
            Text("Album Name")
        }
        HStack {
            AlbumFolderCover(image1: Image(.albumGeneric),
                             image2: Image(.albumGeneric),
                             image3: Image(.albumGeneric))
            .frame(width: 150, height: 150, alignment: .center)
            Text("Album Name")
        }
    }
}
