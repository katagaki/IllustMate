//
//  CarouselThumbnail.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import SwiftUI

struct CarouselThumbnail: View {

    let pic: Pic
    let isSelected: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.05))
            .frame(width: 48.0, height: 48.0)
            .overlay {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .clipShape(.rect(cornerRadius: 4.0))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4.0)
                        .stroke(.accent, lineWidth: 2.0)
                }
            }
            .opacity(isSelected ? 1.0 : 0.6)
            .animation(.smooth.speed(2), value: isSelected)
            .task(id: pic.identifiableString()) {
                let picID = pic.id
                // Check in-memory cache first
                if let cached = ThumbnailCache.shared.image(forKey: picID) {
                    thumbnail = cached
                    return
                }
                // Try pic's in-memory data, else fetch from DB
                let thumbData: Data?
                if let data = pic.thumbnailData {
                    thumbData = data
                } else {
                    thumbData = await DataActor.shared.thumbnailData(forPicWithID: picID)
                }
                if let thumbData, let uiImage = UIImage(data: thumbData),
                   let prepared = await uiImage.byPreparingForDisplay() {
                    guard !Task.isCancelled else { return }
                    ThumbnailCache.shared.setImage(prepared, forKey: picID)
                    thumbnail = prepared
                }
            }
    }
}
