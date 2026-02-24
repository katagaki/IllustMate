//
//  PicLabel.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct PicLabel: View {

    var pic: Pic

    @State var isThumbnailReadyToPresent: Bool = false
    @State var thumbnail: Image?

    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.05))
            .aspectRatio(1.0, contentMode: .fit)
            .overlay {
                if isThumbnailReadyToPresent {
                    Group {
                        if let thumbnail {
                            thumbnail
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24.0, height: 24.0)
                                .foregroundStyle(.primary)
                                .symbolRenderingMode(.multicolor)
                        }
                    }
                    .transition(.opacity.animation(.smooth.speed(2)))
                }
            }
            .clipped()
            .contentShape(.rect)
            .clipShape(.rect(cornerRadius: 4.0))
            .task(id: pic.identifiableString()) {
                if let thumbData = await dataActor.thumbnailData(forPicWithID: pic.id),
                   let uiImage = UIImage(data: thumbData) {
                    pic.thumbnailData = thumbData
                    thumbnail = Image(uiImage: uiImage)
                }
                isThumbnailReadyToPresent = true
            }
    }
}
