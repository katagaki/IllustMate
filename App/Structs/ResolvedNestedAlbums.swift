//
//  ResolvedNestedAlbums.swift
//  PicMate
//
//  Created on 2026/03/15.
//

import Photos

struct ResolvedNestedAlbums {
    let ownPicsCollection: PHAssetCollection?
    let albums: [PHAssetCollection]
    let folders: [PHCollectionList]
}
