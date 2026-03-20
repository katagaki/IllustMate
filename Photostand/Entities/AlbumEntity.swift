//
//  AlbumEntity.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import AppIntents
import WidgetKit

// MARK: - App Entity for Album Selection

struct AlbumEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Photostand.Entity.Album", table: "Widgets")
    )
    static var defaultQuery = AlbumEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct AlbumEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AlbumEntity] {
        PhotostandDatabase.fetchAllAlbums()
            .filter { identifiers.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { AlbumEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [AlbumEntity] {
        PhotostandDatabase.fetchAllAlbums()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { AlbumEntity(id: $0.id, name: $0.name) }
    }
}
