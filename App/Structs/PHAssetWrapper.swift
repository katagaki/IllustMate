//
//  PHAssetWrapper.swift
//  PicMate
//
//  Created on 2026/02/28.
//

import Foundation
import Photos

struct PHAssetWrapper: Hashable {
    let asset: PHAsset

    static func == (lhs: PHAssetWrapper, rhs: PHAssetWrapper) -> Bool {
        lhs.asset.localIdentifier == rhs.asset.localIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(asset.localIdentifier)
    }
}
