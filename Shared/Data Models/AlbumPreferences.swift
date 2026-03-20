//
//  AlbumPreferences.swift
//  PicMate
//
//  Created by Claude on 2026/03/20.
//

import Foundation

struct AlbumPreferences: Sendable {
    var albumID: String
    var albumSort: String
    var albumViewStyle: String
    var albumColumnCount: Int
    var picSort: String
    var picColumnCount: Int

    static let defaults = AlbumPreferences(
        albumID: "",
        albumSort: "nameAscending",
        albumViewStyle: "grid",
        albumColumnCount: 4,
        picSort: "dateAddedDescending",
        picColumnCount: 4
    )
}
