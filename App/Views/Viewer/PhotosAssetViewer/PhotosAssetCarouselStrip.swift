//
//  PhotosAssetCarouselStrip.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import SwiftUI

struct PhotosAssetCarouselStrip: View {

    @Environment(PhotosViewerManager.self) var photosViewer

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4.0) {
                    ForEach(Array(photosViewer.allAssets.enumerated()),
                            id: \.element.localIdentifier) { index, asset in
                        Button {
                            withAnimation(.smooth.speed(2)) {
                                photosViewer.navigateTo(index: index)
                            }
                        } label: {
                            PhotosCarouselThumbnail(
                                asset: asset,
                                isSelected: index == photosViewer.currentIndex
                            )
                        }
                        .buttonStyle(.plain)
                        .id(asset.localIdentifier)
                    }
                }
                .padding(.horizontal, 20.0)
            }
            .frame(height: 56.0)
            .onChange(of: photosViewer.currentIndex) { _, _ in
                if let asset = photosViewer.displayedAsset {
                    withAnimation(.smooth) {
                        proxy.scrollTo(asset.localIdentifier, anchor: .center)
                    }
                }
            }
            .onAppear {
                if let asset = photosViewer.displayedAsset {
                    proxy.scrollTo(asset.localIdentifier, anchor: .center)
                }
            }
        }
    }
}

struct PhotosAssetCarouselStripVertical: View {

    @Environment(PhotosViewerManager.self) var photosViewer

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4.0) {
                    ForEach(Array(photosViewer.allAssets.enumerated()),
                            id: \.element.localIdentifier) { index, asset in
                        Button {
                            withAnimation(.smooth.speed(2)) {
                                photosViewer.navigateTo(index: index)
                            }
                        } label: {
                            PhotosCarouselThumbnail(
                                asset: asset,
                                isSelected: index == photosViewer.currentIndex
                            )
                        }
                        .buttonStyle(.plain)
                        .id(asset.localIdentifier)
                    }
                }
                .padding(.vertical, 8.0)
            }
            .frame(width: 56.0)
            .onChange(of: photosViewer.currentIndex) { _, _ in
                if let asset = photosViewer.displayedAsset {
                    withAnimation(.smooth) {
                        proxy.scrollTo(asset.localIdentifier, anchor: .center)
                    }
                }
            }
            .onAppear {
                if let asset = photosViewer.displayedAsset {
                    proxy.scrollTo(asset.localIdentifier, anchor: .center)
                }
            }
        }
    }
}
