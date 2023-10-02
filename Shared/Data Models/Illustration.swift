//
//  Illustration.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation
import SwiftData

@Model
final class Illustration {
    var id = UUID().uuidString
    var name: String
    var data: Data
    var format: IllustrationFormat
    @Relationship(deleteRule: .nullify, inverse: \Album.illustrations) var containingAlbums: [Album]? = []
    var dateAdded: Date

    init(name: String, data: Data, format: IllustrationFormat, dateAdded: Date) {
        self.name = name
        self.data = data
        self.format = format
        self.dateAdded = dateAdded
    }
}

enum IllustrationFormat: Codable {
    case png
    case jpg
}
