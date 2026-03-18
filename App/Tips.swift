//
//  Tips.swift
//  PicMate
//
//  Created by Claude on 2026/03/18.
//

import TipKit

struct ImportTip: Tip {
    var title: Text {
        Text("Tips.Import.Title", tableName: "Tips")
    }
    var message: Text? {
        Text("Tips.Import.Message", tableName: "Tips")
    }
    var image: Image? {
        Image(systemName: "square.and.arrow.down.on.square")
    }
}

struct NewAlbumTip: Tip {
    var title: Text {
        Text("Tips.NewAlbum.Title", tableName: "Tips")
    }
    var message: Text? {
        Text("Tips.NewAlbum.Message", tableName: "Tips")
    }
    var image: Image? {
        Image(systemName: "rectangle.stack.badge.plus")
    }
}

struct LibrariesTip: Tip {
    var title: Text {
        Text("Tips.Libraries.Title", tableName: "Tips")
    }
    var message: Text? {
        Text("Tips.Libraries.Message", tableName: "Tips")
    }
    var image: Image? {
        Image(systemName: "square.stack.3d.up")
    }
}
