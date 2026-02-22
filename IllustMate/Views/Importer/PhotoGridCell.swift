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

                // Selection indicator
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                            .frame(width: 24, height: 24)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
                .padding(6)

                // Dim unselected
                if !isSelected {
                    Color.black.opacity(0.15)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
