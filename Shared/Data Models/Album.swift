//
//  Item.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation
import SwiftData

@Model
final class Album {
    var id = UUID().uuidString
    var name: String = ""
    var coverPhoto: Data?
    var childAlbums: [Album]? = []
    var childIllustrations: [Illustration]? = []
    @Relationship(deleteRule: .cascade, inverse: \Album.childAlbums) var parentAlbum: Album?
    var dateCreated: Date = Date.now

    init(name: String, dateCreated: Date) {
        self.name = name
        self.dateCreated = dateCreated
    }

    func albums() -> [Album] {
        return childAlbums ?? []
    }

    func illustrations() -> [Illustration] {
        return childIllustrations ?? []
    }

    func addChildAlbum(_ album: Album) {
        childAlbums?.append(album)
    }
}
