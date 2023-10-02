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
    var name: String
    var coverPhoto: Data? = nil
    var illustrations: [Illustration] = []
    var dateCreated: Date

    init(name: String, dateCreated: Date) {
        self.name = name
        self.dateCreated = dateCreated
    }
}
