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

    private let database: Connection

    // Tables
    private nonisolated let albumsTable = Table("albums")
    private nonisolated let illustrationsTable = Table("illustrations")

    // Album columns
    private nonisolated let albumId = Expression<String>("id")
    private nonisolated let albumName = Expression<String>("name")
    private nonisolated let albumCoverPhoto = Expression<Data?>("cover_photo")
    private nonisolated let albumParentId = Expression<String?>("parent_album_id")
    private nonisolated let albumDateCreated = Expression<Double>("date_created")

    // Illustration columns
    private nonisolated let illustrationId = Expression<String>("id")
    private nonisolated let illustrationName = Expression<String>("name")
    private nonisolated let illustrationAlbumId = Expression<String?>("containing_album_id")
    private nonisolated let illustrationDateAdded = Expression<Double>("date_added")
    private nonisolated let illustrationData = Expression<Data>("data")
    private nonisolated let illustrationThumbnailData = Expression<Data?>("thumbnail_data")

    init() {
        let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.IllustMate")!
        let dbURL = containerURL.appendingPathComponent("IllustMate.sqlite")

        // Migrate from old location if needed
        let oldDbURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("IllustMate.sqlite")
        if !FileManager.default.fileExists(atPath: dbURL.path) &&
            FileManager.default.fileExists(atPath: oldDbURL.path) {
            try? FileManager.default.copyItem(at: oldDbURL, to: dbURL)
        }

        let database: Connection
        do {
            database = try Connection(dbURL.path)
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

    func save() {
        // SQLite.swift commits automatically; no-op kept for compatibility
    }

    // MARK: - Row to Model Helpers

    private func albumFrom(row: Row, loadChildren: Bool = false) -> Album {
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

    private func illustrationFrom(row: Row) -> Illustration {
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

    private func fetchChildAlbums(forAlbumID id: String) -> [Album] {
        let query = albumsTable.filter(albumParentId == id)
        return (try? database.prepare(query).map { albumFrom(row: $0, loadChildren: false) }) ?? []
    }

    private func fetchChildIllustrations(forAlbumID id: String) -> [Illustration] {
        let query = illustrationsTable
            .filter(illustrationAlbumId == id)
            .select(illustrationId, illustrationName, illustrationAlbumId,
                    illustrationDateAdded, illustrationThumbnailData)
        return (try? database.prepare(query).map { illustrationFrom(row: $0) }) ?? []
    }

    // MARK: - Albums

    func albums(sortedBy sortType: SortType) throws -> [Album] {
        let rows = try database.prepare(albumsTable)
        let albums = rows.map { albumFrom(row: $0, loadChildren: true) }
        return sortAlbum(albums, sortedBy: sortType)
    }

    func albums(in album: Album?, sortedBy sortType: SortType) throws -> [Album] {
        let query: QueryType
        if let albumID = album?.id {
            query = albumsTable.filter(albumParentId == albumID)
        } else {
            query = albumsTable.filter(albumParentId == nil)
        }
        let rows = try database.prepare(query)
        let albums = rows.map { albumFrom(row: $0, loadChildren: true) }
        return sortAlbum(albums, sortedBy: sortType)
    }

    func albumsWithCounts(sortedBy sortType: SortType) throws -> [Album] {
        let rows = try database.prepare(albumsTable)
        let albums = rows.map { row -> Album in
            let album = albumFrom(row: row, loadChildren: false)
            album.childAlbumCount = albumCount(forAlbumWithID: album.id)
            album.childIllustrationCount = illustrationCount(forAlbumWithID: album.id)
            return album
        }
        return sortAlbum(albums, sortedBy: sortType)
    }

    func albumsWithCounts(in album: Album?, sortedBy sortType: SortType) throws -> [Album] {
        let query: QueryType
        if let albumID = album?.id {
            query = albumsTable.filter(albumParentId == albumID)
        } else {
            query = albumsTable.filter(albumParentId == nil)
        }
        let rows = try database.prepare(query)
        let albums = rows.map { row -> Album in
            let album = albumFrom(row: row, loadChildren: false)
            album.childAlbumCount = albumCount(forAlbumWithID: album.id)
            album.childIllustrationCount = illustrationCount(forAlbumWithID: album.id)
            return album
        }
        return sortAlbum(albums, sortedBy: sortType)
    }

    func representativeThumbnails(forAlbumWithID albumID: String, limit: Int = 3) -> [Data] {
        let query = illustrationsTable
            .filter(illustrationAlbumId == albumID)
            .select(illustrationThumbnailData)
            .order(illustrationDateAdded.asc)
            .limit(limit)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { try? $0.get(illustrationThumbnailData) }
    }

    func album(for id: String) -> Album? {
        let query = albumsTable.filter(albumId == id)
        return try? database.pluck(query).map { albumFrom(row: $0, loadChildren: true) }
    }

    func createAlbum(_ name: String) -> Album {
        let id = UUID().uuidString
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let now = Date.now
        let album = Album(id: id, name: trimmedName, dateCreated: now)
        _ = try? database.run(albumsTable.insert(
            albumId <- id,
            albumName <- trimmedName,
            albumCoverPhoto <- nil,
            albumParentId <- nil,
            albumDateCreated <- now.timeIntervalSince1970
        ))
        return album
    }

    func renameAlbum(withID id: String, to newName: String) {
        let query = albumsTable.filter(albumId == id)
        _ = try? database.run(query.update(albumName <- newName.trimmingCharacters(in: .whitespaces)))
    }

    func updateAlbumCover(forAlbumWithID albumID: String, coverData: Data?) {
        let query = albumsTable.filter(albumId == albumID)
        _ = try? database.run(query.update(albumCoverPhoto <- coverData))
    }

    func sortAlbum(_ albums: [Album], sortedBy sortType: SortType) -> [Album] {
        switch sortType {
        case .nameAscending: return albums.sorted(by: { $0.name < $1.name })
        case .nameDescending: return albums.sorted(by: { $0.name > $1.name })
        case .sizeAscending:
            return albums.sorted(by: {
                $0.albumCount() + $0.illustrationCount() <
                $1.albumCount() + $1.illustrationCount()
            })
        case .sizeDescending:
            return albums.sorted(by: {
                $0.albumCount() + $0.illustrationCount() >
                $1.albumCount() + $1.illustrationCount()
            })
        }
    }

    func objectCount(forAlbumWithID id: String) -> Int {
        return albumCount(forAlbumWithID: id) + illustrationCount(forAlbumWithID: id)
    }

    func albumCount(forAlbumWithID id: String) -> Int {
        let query = albumsTable.filter(albumParentId == id)
        return (try? database.scalar(query.count)) ?? 0
    }

    func illustrationCount() -> Int {
        return (try? database.scalar(illustrationsTable.count)) ?? 0
    }

    func illustrationCount(forAlbumWithID id: String) -> Int {
        let query = illustrationsTable.filter(illustrationAlbumId == id)
        return (try? database.scalar(query.count)) ?? 0
    }

    func albumCount() -> Int {
        return (try? database.scalar(albumsTable.count)) ?? 0
    }

    func addAlbum(withID albumID: String, toAlbumWithID destinationAlbumID: String) {
        let query = albumsTable.filter(albumId == albumID)
        _ = try? database.run(query.update(albumParentId <- destinationAlbumID))
    }

    func removeParentAlbum(forAlbumWithidentifier albumID: String) {
        let query = albumsTable.filter(albumId == albumID)
        _ = try? database.run(query.update(albumParentId <- nil))
    }

    func deleteAlbum(withID albumID: String) {
        let parentID = parentAlbumID(forAlbumWithID: albumID)

        // Move direct illustrations to parent album, or orphan them
        let illustQuery = illustrationsTable.filter(illustrationAlbumId == albumID)
        if let parentID = parentID {
            _ = try? database.run(illustQuery.update(illustrationAlbumId <- parentID))
        } else {
            _ = try? database.run(illustQuery.update(illustrationAlbumId <- nil))
        }

        // Recursively delete child albums
        deleteAlbumCascade(withID: albumID)
    }

    private func deleteAlbumCascade(withID albumID: String) {
        // Orphan all illustrations in this album
        let illustQuery = illustrationsTable.filter(illustrationAlbumId == albumID)
        _ = try? database.run(illustQuery.update(illustrationAlbumId <- nil))

        // Recurse into child albums
        let childQuery = albumsTable.filter(albumParentId == albumID)
        if let rows = try? database.prepare(childQuery) {
            for row in rows {
                if let childID = try? row.get(albumId) {
                    deleteAlbumCascade(withID: childID)
                }
            }
        }

        // Delete the album
        let album = albumsTable.filter(albumId == albumID)
        _ = try? database.run(album.delete())
    }

    private func parentAlbumID(forAlbumWithID albumID: String) -> String? {
        let query = albumsTable.filter(albumId == albumID).select(albumParentId)
        return try? database.pluck(query).flatMap { try? $0.get(albumParentId) }
    }

}

// MARK: - Illustrations

extension DataActor {

    func illustrations() throws -> [Illustration] {
        let query = illustrationsTable
            .select(illustrationId, illustrationName, illustrationAlbumId,
                    illustrationDateAdded, illustrationThumbnailData)
            .order(illustrationDateAdded.desc)
        return try database.prepare(query).map { illustrationFrom(row: $0) }
    }

    func illustrations(in album: Album?, order: SortOrder) throws -> [Illustration] {
        let baseQuery: SQLite.Table
        if let albumID = album?.id {
            baseQuery = illustrationsTable.filter(illustrationAlbumId == albumID)
        } else {
            baseQuery = illustrationsTable.filter(illustrationAlbumId == nil)
        }
        let orderedQuery = (order == .reverse ? baseQuery.order(illustrationDateAdded.desc) :
                                                baseQuery.order(illustrationDateAdded.asc))
            .select(illustrationId, illustrationName, illustrationAlbumId,
                    illustrationDateAdded, illustrationThumbnailData)
        return try database.prepare(orderedQuery).map { illustrationFrom(row: $0) }
    }

    func illustrationSkeletons(in album: Album?, order: SortOrder) throws -> [Illustration] {
        let baseQuery: SQLite.Table
        if let albumID = album?.id {
            baseQuery = illustrationsTable.filter(illustrationAlbumId == albumID)
        } else {
            baseQuery = illustrationsTable.filter(illustrationAlbumId == nil)
        }
        let orderedQuery = (order == .reverse ? baseQuery.order(illustrationDateAdded.desc) :
                                                baseQuery.order(illustrationDateAdded.asc))
            .select(illustrationId, illustrationName, illustrationAlbumId,
                    illustrationDateAdded)
        return try database.prepare(orderedQuery).map { illustrationFrom(row: $0) }
    }

    func thumbnailData(forIllustrationWithID id: String) -> Data? {
        let query = illustrationsTable
            .filter(illustrationId == id)
            .select(illustrationThumbnailData)
        return try? database.pluck(query).flatMap { try? $0.get(illustrationThumbnailData) }
    }

    func illustration(for id: String) -> Illustration? {
        let query = illustrationsTable
            .filter(illustrationId == id)
            .select(illustrationId, illustrationName, illustrationAlbumId,
                    illustrationDateAdded, illustrationThumbnailData)
        return try? database.pluck(query).map { illustrationFrom(row: $0) }
    }

    func imageData(forIllustrationWithID id: String) -> Data? {
        let query = illustrationsTable
            .filter(illustrationId == id)
            .select(illustrationData)
        return try? database.pluck(query).flatMap { try? $0.get(illustrationData) }
    }

    func createIllustration(_ name: String, data: Data, inAlbumWithID albumID: String? = nil) {
        let id = UUID().uuidString
        let now = Date.now
        let thumbnailData = Illustration.makeThumbnail(data)
        _ = try? database.run(illustrationsTable.insert(
            illustrationId <- id,
            illustrationName <- name,
            illustrationAlbumId <- albumID,
            illustrationDateAdded <- now.timeIntervalSince1970,
            illustrationData <- data,
            illustrationThumbnailData <- thumbnailData
        ))
    }

    func addIllustrations(withIDs illustrationIDs: [String], toAlbumWithID albumID: String) {
        for illustrationID in illustrationIDs {
            let query = illustrationsTable.filter(illustrationId == illustrationID)
            _ = try? database.run(query.update(illustrationAlbumId <- albumID))
        }
    }

    func addIllustration(withID illustrationID: String, toAlbumWithID albumID: String) {
        let query = illustrationsTable.filter(illustrationId == illustrationID)
        _ = try? database.run(query.update(illustrationAlbumId <- albumID))
    }

    func removeParentAlbum(forIllustrationWithID illustrationID: String) {
        let query = illustrationsTable.filter(illustrationId == illustrationID)
        _ = try? database.run(query.update(illustrationAlbumId <- nil))
    }

    func removeParentAlbum(forIllustrationsWithIDs illustrationIDs: [String]) {
        for illustrationID in illustrationIDs {
            let query = illustrationsTable.filter(illustrationId == illustrationID)
            _ = try? database.run(query.update(illustrationAlbumId <- nil))
        }
    }

    func setAsAlbumCover(for illustrationID: String) {
        if let data = imageData(forIllustrationWithID: illustrationID),
           let albumID = containingAlbumID(forIllustrationWithID: illustrationID) {
            let coverData = Album.makeCover(data)
            let query = albumsTable.filter(albumId == albumID)
            _ = try? database.run(query.update(albumCoverPhoto <- coverData))
        }
    }

    func renameIllustration(withID illustrationID: String, to newName: String) {
        let query = illustrationsTable.filter(illustrationId == illustrationID)
        _ = try? database.run(query.update(illustrationName <- newName))
    }

    func updateThumbnail(forIllustrationWithID illustrationID: String, thumbnailData: Data?) {
        let query = illustrationsTable.filter(illustrationId == illustrationID)
        _ = try? database.run(query.update(illustrationThumbnailData <- thumbnailData))
    }

    private func containingAlbumID(forIllustrationWithID illustrationID: String) -> String? {
        let query = illustrationsTable
            .filter(illustrationId == illustrationID)
            .select(illustrationAlbumId)
        return try? database.pluck(query).flatMap { try? $0.get(illustrationAlbumId) }
    }

    func deleteIllustration(withID illustrationID: String) {
        let query = illustrationsTable.filter(illustrationId == illustrationID)
        _ = try? database.run(query.delete())
    }

    // MARK: - Thumbnails (stored within illustrations table)

    func thumbnailCount() -> Int {
        let query = illustrationsTable.filter(illustrationThumbnailData != nil)
        return (try? database.scalar(query.count)) ?? 0
    }

    func deleteAllThumbnails() {
        _ = try? database.run(illustrationsTable.update(illustrationThumbnailData <- nil))
    }

    // MARK: - Delete All

    func deleteAll() {
        _ = try? database.run(illustrationsTable.delete())
        _ = try? database.run(albumsTable.delete())
    }
}
