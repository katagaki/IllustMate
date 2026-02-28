//
//  ViewPath.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation
import Photos
import UIKit
import SwiftUI

enum ViewPath: Hashable {
    case collection
    case albums
    case pics
    case picViewer(namespace: Namespace.ID)
    case album(album: Album)
    case more
    case moreDebug
    case moreTroubleshooting
    case moreAttributions
    case photosFolder(folder: PHCollectionListWrapper)
    case photosAlbum(album: PHAssetCollectionWrapper)
    case photosAssetViewer(asset: PHAssetWrapper)
}
