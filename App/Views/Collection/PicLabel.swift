//
//  PicLabel.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 500
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

struct PicLabel: View {

    var pic: Pic

    @State var isThumbnailReadyToPresent: Bool = false
    @State var thumbnail: Image?

    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.05))
            .aspectRatio(1.0, contentMode: .fit)
            .overlay(alignment: .top) {
                if isThumbnailReadyToPresent, let thumbnail {
                    thumbnail
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity.animation(.smooth.speed(2.0)))
                }
            }
            .overlay {
                if isThumbnailReadyToPresent, thumbnail == nil {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24.0, height: 24.0)
                        .foregroundStyle(.primary)
                        .symbolRenderingMode(.multicolor)
                        .transition(.opacity.animation(.smooth.speed(2.0)))
                }
            }
            .clipped()
            .contentShape(.rect)
            .clipShape(.rect(cornerRadius: 4.0))
            .task(id: pic.id) {
                let picID = pic.id
                if let cached = ThumbnailCache.shared.image(forKey: picID) {
                    thumbnail = Image(uiImage: cached)
                    isThumbnailReadyToPresent = true
                    return
                }
                var thumbData = pic.thumbnailData
                if thumbData == nil {
                    thumbData = await DataActor.shared.thumbnailData(forPicWithID: picID)
                }
                if let thumbData,
                   let uiImage = UIImage(data: thumbData),
                   let prepared = await uiImage.byPreparingForDisplay() {
                    guard !Task.isCancelled else { return }
                    ThumbnailCache.shared.setImage(prepared, forKey: picID)
                    thumbnail = Image(uiImage: prepared)
                }
                isThumbnailReadyToPresent = true
            }
    }
}
