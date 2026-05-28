//
//  LibraryEntity.swift
//  PicMate
//
//  Created by Claude on 2026/05/29.
//

import AppIntents
import WidgetKit

struct LibraryEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Photostand.Entity.Library", table: "Widgets")
    )
    static var defaultQuery = LibraryEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    /// The default library has an empty stored name and is shown as "Collection".
    static func displayName(forID id: String, name: String) -> String {
        if id == PhotostandDatabase.defaultLibraryID || name.isEmpty {
            return String(localized: "Library.Default", table: "Widgets")
        }
        return name
    }

    static func entity(from record: PhotostandDatabase.LibraryRecord) -> LibraryEntity {
        LibraryEntity(id: record.id, name: displayName(forID: record.id, name: record.name))
    }
}

struct LibraryEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LibraryEntity] {
        PhotostandDatabase.fetchAllLibraries()
            .filter { identifiers.contains($0.id) }
            .map { LibraryEntity.entity(from: $0) }
    }

    func suggestedEntities() async throws -> [LibraryEntity] {
        sorted(PhotostandDatabase.fetchAllLibraries()).map { LibraryEntity.entity(from: $0) }
    }

    /// Default library first, then alphabetical.
    private func sorted(_ records: [PhotostandDatabase.LibraryRecord]) -> [PhotostandDatabase.LibraryRecord] {
        records.sorted { lhs, rhs in
            if lhs.id == PhotostandDatabase.defaultLibraryID { return true }
            if rhs.id == PhotostandDatabase.defaultLibraryID { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
