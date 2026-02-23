//
//  DataActor.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/17.
//

import Foundation
@preconcurrency import SQLite
import SwiftUI

actor DataActor {

    let database: Connection

    // Tables
    let albumsTable = Table("albums")
    let illustrationsTable = Table("illustrations")

    // Album columns
    let albumId = Expression<String>("id")
    let albumName = Expression<String>("name")
    let albumCoverPhoto = Expression<Data?>("cover_photo")
    let albumParentId = Expression<String?>("parent_album_id")
    let albumDateCreated = Expression<Double>("date_created")

    // Illustration columns
    let illustrationId = Expression<String>("id")
    let illustrationName = Expression<String>("name")
    let illustrationAlbumId = Expression<String?>("containing_album_id")
    let illustrationDateAdded = Expression<Double>("date_added")
    let illustrationData = Expression<Data>("data")
    let illustrationThumbnailData = Expression<Data?>("thumbnail_data")

    init() {
        let databaseFileName = "Collection.db"
        let databaseURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(databaseFileName)

        let database: Connection
        do {
            database = try Connection(databaseURL.path)
        } catch {
            fatalError("Could not open SQLite database: \(error)")
        }
        self.database = database
        do {
            try database.run(albumsTable.create(ifNotExists: true) { table in
                table.column(albumId, primaryKey: true)
                table.column(albumName)
                table.column(albumCoverPhoto)
                table.column(albumParentId)
                table.column(albumDateCreated)
            })
            try database.run(illustrationsTable.create(ifNotExists: true) { table in
                table.column(illustrationId, primaryKey: true)
                table.column(illustrationName)
                table.column(illustrationAlbumId)
                table.column(illustrationDateAdded)
                table.column(illustrationData)
                table.column(illustrationThumbnailData)
            })
            try database.run(albumsTable.createIndex(albumParentId, ifNotExists: true))
            try database.run(illustrationsTable.createIndex(illustrationAlbumId, ifNotExists: true))
        } catch {
            debugPrint("Database setup error: \(error)")
        }
    }

    // MARK: - Row to Model Helpers

    func albumFrom(row: Row, loadChildren: Bool = false) -> Album {
        let id = (try? row.get(albumId)) ?? ""
        let name = (try? row.get(albumName)) ?? ""
        let cover = try? row.get(albumCoverPhoto)
        let parentId = try? row.get(albumParentId)
        let dateCreated = Date(timeIntervalSince1970: (try? row.get(albumDateCreated)) ?? 0)
        let album = Album(id: id, name: name, coverPhoto: cover ?? nil,
                          parentAlbumID: parentId ?? nil, dateCreated: dateCreated)
        if loadChildren {
            album.childAlbums = fetchChildAlbums(forAlbumID: id)
            album.childIllustrations = fetchChildIllustrations(forAlbumID: id)
        }
        return album
    }

    func illustrationFrom(row: Row) -> Illustration {
        let id = (try? row.get(illustrationId)) ?? ""
        let name = (try? row.get(illustrationName)) ?? ""
        let albumId = try? row.get(illustrationAlbumId)
        let dateAdded = Date(timeIntervalSince1970: (try? row.get(illustrationDateAdded)) ?? 0)
        let thumbData = try? row.get(illustrationThumbnailData)
        let illustration = Illustration(id: id, name: name,
                                        containingAlbumID: albumId ?? nil,
                                        dateAdded: dateAdded)
        illustration.thumbnailData = thumbData ?? nil
        return illustration
    }

    func fetchChildAlbums(forAlbumID id: String) -> [Album] {
        let query = albumsTable.filter(albumParentId == id)
        return (try? database.prepare(query).map { albumFrom(row: $0, loadChildren: false) }) ?? []
    }

    func fetchChildIllustrations(forAlbumID id: String) -> [Illustration] {
        let query = illustrationsTable
            .filter(illustrationAlbumId == id)
            .select(illustrationId, illustrationName, illustrationAlbumId,
                    illustrationDateAdded, illustrationThumbnailData)
        return (try? database.prepare(query).map { illustrationFrom(row: $0) }) ?? []
    }
}
