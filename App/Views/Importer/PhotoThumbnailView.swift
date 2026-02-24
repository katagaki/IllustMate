//
//  PhotoThumbnailView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/02/22.
//

import Photos
import SwiftUI

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let asset: PHAsset
    let size: CGSize

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color(.systemGray5)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let manager = PHCachingImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: size.width * displayScale, height: size.height * displayScale)

        manager.requestImage(for: asset, targetSize: targetSize,
                             contentMode: .aspectFill, options: options) { result, _ in
            if let result {
                DispatchQueue.main.async {
                    self.image = result
                }
            }
        }
    }
}
