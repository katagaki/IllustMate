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
    case photosAssetViewer(asset: PHAssetWrapper, namespace: Namespace.ID)
    case picViewerRestore
    case photosAssetViewerRestore
}
