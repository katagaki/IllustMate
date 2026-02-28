//
//  PhotosAssetsGrid.swift
//  PicMate
//
//  Created on 2026/02/26.
//

import Photos
import SwiftUI

struct PhotosAssetsGrid: View {

    var namespace: Namespace.ID
    var assets: [PHAsset]

    @AppStorage(wrappedValue: 4, "PicColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var columnCount: Int

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2.0), count: columnCount),
            spacing: 2.0
        ) {
            ForEach(assets, id: \.localIdentifier) { asset in
                NavigationLink(value: ViewPath.photosAssetViewer(
                    asset: PHAssetWrapper(asset: asset), namespace: namespace)) {
                    PhotosAssetLabel(asset: asset)
                }
                .matchedTransitionSource(id: asset.localIdentifier, in: namespace)
#if targetEnvironment(macCatalyst)
                .buttonStyle(.borderless)
#else
                .buttonStyle(.plain)
#endif
            }
        }
        .animation(.smooth, value: columnCount)
    }
}

struct PhotosAssetLabel: View {

    let asset: PHAsset

    @Environment(\.displayScale) private var displayScale

    @State private var thumbnail: UIImage?

    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.05))
            .aspectRatio(1.0, contentMode: .fit)
            .overlay { geometryOverlay }
            .clipped()
            .contentShape(.rect)
            .clipShape(.rect(cornerRadius: 4.0))
    }

    private var geometryOverlay: some View {
        GeometryReader { metrics in
            ZStack {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity.animation(.smooth.speed(2)))
                }
            }
            .frame(width: metrics.size.width, height: metrics.size.height)
            .task(id: asset.localIdentifier) {
                loadThumbnail(cellSize: metrics.size)
            }
        }
    }

    private func loadThumbnail(cellSize: CGSize) {
        let manager = PHCachingImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        let targetSize = CGSize(width: cellSize.width * displayScale,
                                height: cellSize.height * displayScale)

        manager.requestImage(for: asset, targetSize: targetSize,
                             contentMode: .aspectFill, options: options) { result, _ in
            if let result {
                DispatchQueue.main.async {
                    self.thumbnail = result
                }
            }
        }
    }
}
