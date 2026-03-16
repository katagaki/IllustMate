//
//  Drop.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/12.
//

import CoreTransferable
import Foundation
import SwiftUI

enum Drop: Transferable {
    case album(AlbumTransferable)
    case pic(PicTransferable)
    case pics(PicCollectionTransferable)
    case importedPhoto(Image)

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { Drop.album($0) }
        ProxyRepresentation { Drop.pics($0) }
        ProxyRepresentation { Drop.pic($0) }
        ProxyRepresentation { Drop.importedPhoto($0) }
    }

    var album: AlbumTransferable? {
        if case .album(let album) = self { return album }
        return nil
    }

    var pic: PicTransferable? {
        if case .pic(let pic) = self { return pic }
        return nil
    }

    var pics: PicCollectionTransferable? {
        if case .pics(let pics) = self { return pics }
        return nil
    }

    var importedPhoto: Image? {
        if case .importedPhoto(let importedPhoto) = self { return importedPhoto }
        return nil
    }
}
