//
//  PHCollectionListWrapper.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/02/22.
//

import Foundation
import Photos

struct PHCollectionListWrapper: Hashable {
    let collectionList: PHCollectionList

    static func == (lhs: PHCollectionListWrapper, rhs: PHCollectionListWrapper) -> Bool {
        lhs.collectionList.localIdentifier == rhs.collectionList.localIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(collectionList.localIdentifier)
    }
}
