//
//  Collection.swift
//  PicMate
//
//  Created by Claude on 2026/03/17.
//

import Foundation

final class Collection: Identifiable, Hashable, @unchecked Sendable {
    static let defaultID = "__default__"

    var id: String
    var name: String

    var isDefault: Bool { id == Self.defaultID }

    init(id: String = Self.defaultID, name: String = "") {
        self.id = id
        self.name = name
    }

    static func == (lhs: Collection, rhs: Collection) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }

    static func newID() -> String {
        let digits = String(format: "%08d", Int.random(in: 0...99_999_999))
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        let alphanumeric = String((0..<4).map { _ in chars.randomElement()! })
        return "\(digits)-\(alphanumeric)"
    }
}
