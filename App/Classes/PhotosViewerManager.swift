//
//  PhotosViewerManager.swift
//  PicMate
//
//  Created on 2026/03/08.
//

import Foundation
import Photos
import SwiftUI

@MainActor @Observable
class PhotosViewerManager {

    var displayedAsset: PHAsset?
    var allAssets: [PHAsset] = []
    var currentIndex: Int = 0

    var hasNext: Bool { currentIndex < allAssets.count - 1 }
    var hasPrevious: Bool { currentIndex > 0 }

    func setDisplay(_ asset: PHAsset, in assets: [PHAsset]) {
        allAssets = assets
        currentIndex = assets.firstIndex(where: {
            $0.localIdentifier == asset.localIdentifier
        }) ?? 0
        displayedAsset = asset
    }

    func navigateTo(index: Int) {
        guard index >= 0, index < allAssets.count else { return }
        currentIndex = index
        displayedAsset = allAssets[index]
    }

    func navigateToNext() {
        if hasNext {
            navigateTo(index: currentIndex + 1)
        }
    }

    func navigateToPrevious() {
        if hasPrevious {
            navigateTo(index: currentIndex - 1)
        }
    }
}
