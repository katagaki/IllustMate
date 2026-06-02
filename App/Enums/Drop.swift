import CoreTransferable
import Foundation
import SwiftUI

enum Drop: Transferable {
    case album(AlbumTransferable)
    case pic(PicTransferable)
    case file(URL)
    case importedPhoto(Image)

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { Drop.album($0) }
        ProxyRepresentation { Drop.pic($0) }
        ProxyRepresentation { Drop.file($0) }
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

    var file: URL? {
        if case .file(let url) = self { return url }
        return nil
    }

    var importedPhoto: Image? {
        if case .importedPhoto(let importedPhoto) = self { return importedPhoto }
        return nil
    }
}
