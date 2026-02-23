//
//  PhotoGridCell.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2026/02/22.
//

import Photos
import SwiftUI

// MARK: - Photo Grid Cell

struct PhotoGridCell: View {
    let asset: PHAsset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                PhotoThumbnailView(asset: asset, size: CGSize(width: 100, height: 100))
                    .frame(minWidth: 80, minHeight: 80)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                SelectionOverlay(isSelected)
                if !isSelected {
                    Color.black.opacity(0.15)
                }
            }
            .clipShape(.rect(cornerRadius: 3.0))
        }
        .buttonStyle(.plain)
    }
}
