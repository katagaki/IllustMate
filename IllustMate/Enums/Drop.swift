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
    case illustration(IllustrationTransferable)
    case importedPhoto(Image)

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { Drop.album($0) }
        ProxyRepresentation { Drop.illustration($0) }
        ProxyRepresentation { Drop.importedPhoto($0) }
    }

    var album: AlbumTransferable? {
        if case .album(let album) = self { return album }
        return nil
    }

    var illustration: IllustrationTransferable? {
        if case .illustration(let illustration) = self { return illustration }
        return nil
    }

    var importedPhoto: Image? {
        if case .importedPhoto(let importedPhoto) = self { return importedPhoto }
        return nil
    }
}
