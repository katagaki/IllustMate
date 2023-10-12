//
//  Drop.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/12.
//

import CoreTransferable
import Foundation
import SwiftData
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
        switch self {
        case .album(let album): return album
        default: return nil
        }
    }

    var illustration: IllustrationTransferable? {
        switch self {
        case.illustration(let illustration): return illustration
        default: return nil
        }
    }

    var importedPhoto: Image? {
        switch self {
        case.importedPhoto(let importedPhoto): return importedPhoto
        default: return nil
        }
    }
}
