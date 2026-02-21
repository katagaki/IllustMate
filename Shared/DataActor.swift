//
//  DataActor.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/17.
//

import Foundation
import SQLite
import SwiftUI

actor DataActor {

    private let db: Connection

    // Tables
    private let albumsTable = Table("albums")
    private let illustrationsTable = Table("illustrations")

    // Album columns
    private let albumId = Expression<String>("id")
    private let albumName = Expression<String>("name")
    private let albumCoverPhoto = Expression<Data?>("cover_photo")
    private let albumParentId = Expression<String?>("parent_album_id")
    private let albumDateCreated = Expression<Double>("date_created")

    // Illustration columns
    private let illustrationId = Expression<String>("id")
    private let illustrationName = Expression<String>("name")
    private let illustrationAlbumId = Expression<String?>("containing_album_id")
    private let illustrationDateAdded = Expression<Double>("date_added")
    private let illustrationData = Expression<Data>("data")
    private let illustrationThumbnailData = Expression<Data?>("thumbnail_data")

    init(db: Connection) {
        self.db = db
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            try db.run(albumsTable.create(ifNotExists: true) { t in
                t.column(albumId, primaryKey: true)
                t.column(albumName)
                t.column(albumCoverPhoto)
                t.column(albumParentId)
                t.column(albumDateCreated)
            })
            try db.run(illustrationsTable.create(ifNotExists: true) { t in
                t.column(illustrationId, primaryKey: true)
                t.column(illustrationName)
                t.column(illustrationAlbumId)
                t.column(illustrationDateAdded)
                t.column(illustrationData)
                t.column(illustrationThumbnailData)
            })
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
        return (try? db.prepare(query).map { albumFrom(row: $0, loadChildren: false) }) ?? []
    }

    private func fetchChildIllustrations(forAlbumID id: String) -> [Illustration] {
        let query = illustrationsTable
            .filter(illustrationAlbumId == id)
            .select(illustrationId, illustrationName, illustrationAlbumId,
                    illustrationDateAdded, illustrationThumbnailData)
        return (try? db.prepare(query).map { illustrationFrom(row: $0) }) ?? []
    }

    // MARK: - Albums

    func albums(sortedBy sortType: SortType) throws -> [Album] {
        let rows = try db.prepare(albumsTable)
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
        let rows = try db.prepare(query)
        let albums = rows.map { albumFrom(row: $0, loadChildren: true) }
        return sortAlbum(albums, sortedBy: sortType)
    }

    func album(for id: String) -> Album? {
        let query = albumsTable.filter(albumId == id)
        return try? db.pluck(query).map { albumFrom(row: $0, loadChildren: true) }
    }

    func createAlbum(_ name: String) -> Album {
        let id = UUID().uuidString
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let now = Date.now
        let album = Album(id: id, name: trimmedName, dateCreated: now)
        try? db.run(albumsTable.insert(
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
        try? db.run(query.update(albumName <- newName.trimmingCharacters(in: .whitespaces)))
    }

    func updateAlbumCover(forAlbumWithID albumID: String, coverData: Data?) {
        let query = albumsTable.filter(albumId == albumID)
        try? db.run(query.update(albumCoverPhoto <- coverData))
    }

    func sortAlbum(_ albums: [Album], sortedBy sortType: SortType) -> [Album] {
        switch sortType {
        case .nameAscending: albums.sorted(by: { $0.name < $1.name })
        case .nameDescending: albums.sorted(by: { $0.name > $1.name })
        case .sizeAscending:
            albums.sorted(by: {
                objectCount(forAlbumWithID: $0.id) < objectCount(forAlbumWithID: $1.id)
            })
        case .sizeDescending:
            albums.sorted(by: {
                objectCount(forAlbumWithID: $0.id) > objectCount(forAlbumWithID: $1.id)
            })
        }
    }

    func objectCount(forAlbumWithID id: String) -> Int {
        return albumCount(forAlbumWithID: id) + illustrationCount(forAlbumWithID: id)
    }

    func albumCount(forAlbumWithID id: String) -> Int {
        let query = albumsTable.filter(albumParentId == id)
        return (try? db.scalar(query.count)) ?? 0
    }

    func illustrationCount() -> Int {
        return (try? db.scalar(illustrationsTable.count)) ?? 0
    }

    func illustrationCount(forAlbumWithID id: String) -> Int {
        let query = illustrationsTable.filter(illustrationAlbumId == id)
        return (try? db.scalar(query.count)) ?? 0
    }

    func albumCount() -> Int {
        return (try? db.scalar(albumsTable.count)) ?? 0
    }

    func addAlbum(withID albumID: String, toAlbumWithID destinationAlbumID: String) {
        let query = albumsTable.filter(albumId == albumID)
        try? db.run(query.update(albumParentId <- destinationAlbumID))
    }

    func removeParentAlbum(forAlbumWithidentifier albumID: String) {
        let query = albumsTable.filter(albumId == albumID)
        try? db.run(query.update(albumParentId <- nil))
    }

    func deleteAlbum(withID albumID: String) {
        let parentID = parentAlbumID(forAlbumWithID: albumID)

        // Move direct illustrations to parent album, or orphan them
        let illustQuery = illustrationsTable.filter(illustrationAlbumId == albumID)
        if let parentID = parentID {
            try? db.run(illustQuery.update(illustrationAlbumId <- parentID))
        } else {
            try? db.run(illustQuery.update(illustrationAlbumId <- nil))
        }

        // Recursively delete child albums
        deleteAlbumCascade(withID: albumID)
    }

    private func deleteAlbumCascade(withID albumID: String) {
        // Orphan all illustrations in this album
        let illustQuery = illustrationsTable.filter(illustrationAlbumId == albumID)
        try? db.run(illustQuery.update(illustrationAlbumId <- nil))

        // Recurse into child albums
        let childQuery = albumsTable.filter(albumParentId == albumID)
        if let rows = try? db.prepare(childQuery) {
            for row in rows {
                if let childID = try? row.get(albumId) {
                    deleteAlbumCascade(withID: childID)
                }
            }
        }

        // Delete the album
        let album = albumsTable.filter(albumId == albumID)
        try? db.run(album.delete())
    }

    private func parentAlbumID(forAlbumWithID albumID: String) -> String? {
        let query = albumsTable.filter(albumId == albumID).select(albumParentId)
        return try? db.pluck(query).flatMap { try? $0.get(albumParentId) }
    }

    // MARK: - Illustrations

    func illustrations() throws -> [Illustration] {
        let query = illustrationsTable
            .select(illustrationId, illustrationName, illustrationAlbumId,
                    illustrationDateAdded, illustrationThumbnailData)
            .order(illustrationDateAdded.desc)
        return try db.prepare(query).map { illustrationFrom(row: $0) }
    }

    func illustrations(in album: Album?, order: SortOrder) throws -> [Illustration] {
        let baseQuery: Table
        if let albumID = album?.id {
            baseQuery = illustrationsTable.filter(illustrationAlbumId == albumID)
        } else {
            baseQuery = illustrationsTable.filter(illustrationAlbumId == nil)
        }
        let orderedQuery = (order == .reverse ? baseQuery.order(illustrationDateAdded.desc) :
                                                baseQuery.order(illustrationDateAdded.asc))
            .select(illustrationId, illustrationName, illustrationAlbumId,
                    illustrationDateAdded, illustrationThumbnailData)
        return try db.prepare(orderedQuery).map { illustrationFrom(row: $0) }
    }

    func illustration(for id: String) -> Illustration? {
        let query = illustrationsTable
            .filter(illustrationId == id)
            .select(illustrationId, illustrationName, illustrationAlbumId,
                    illustrationDateAdded, illustrationThumbnailData)
        return try? db.pluck(query).map { illustrationFrom(row: $0) }
    }

    func imageData(forIllustrationWithID id: String) -> Data? {
        let query = illustrationsTable
            .filter(illustrationId == id)
            .select(illustrationData)
        return try? db.pluck(query).flatMap { try? $0.get(illustrationData) }
    }

    func createIllustration(_ name: String, data: Data, inAlbumWithID albumID: String? = nil) {
        let id = UUID().uuidString
        let now = Date.now
        let thumbnailData = Illustration.makeThumbnail(data)
        try? db.run(illustrationsTable.insert(
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
            try? db.run(query.update(illustrationAlbumId <- albumID))
        }
    }

    func addIllustration(withID illustrationID: String, toAlbumWithID albumID: String) {
        let query = illustrationsTable.filter(illustrationId == illustrationID)
        try? db.run(query.update(illustrationAlbumId <- albumID))
    }

    func removeParentAlbum(forIllustrationWithID illustrationID: String) {
        let query = illustrationsTable.filter(illustrationId == illustrationID)
        try? db.run(query.update(illustrationAlbumId <- nil))
    }

    func removeParentAlbum(forIllustrationsWithIDs illustrationIDs: [String]) {
        for illustrationID in illustrationIDs {
            let query = illustrationsTable.filter(illustrationId == illustrationID)
            try? db.run(query.update(illustrationAlbumId <- nil))
        }
    }

    func setAsAlbumCover(for illustrationID: String) {
        if let data = imageData(forIllustrationWithID: illustrationID),
           let albumID = containingAlbumID(forIllustrationWithID: illustrationID) {
            let coverData = Album.makeCover(data)
            let query = albumsTable.filter(albumId == albumID)
            try? db.run(query.update(albumCoverPhoto <- coverData))
        }
    }

    func renameIllustration(withID illustrationID: String, to newName: String) {
        let query = illustrationsTable.filter(illustrationId == illustrationID)
        try? db.run(query.update(illustrationName <- newName))
    }

    func updateThumbnail(forIllustrationWithID illustrationID: String, thumbnailData: Data?) {
        let query = illustrationsTable.filter(illustrationId == illustrationID)
        try? db.run(query.update(illustrationThumbnailData <- thumbnailData))
    }

    private func containingAlbumID(forIllustrationWithID illustrationID: String) -> String? {
        let query = illustrationsTable
            .filter(illustrationId == illustrationID)
            .select(illustrationAlbumId)
        return try? db.pluck(query).flatMap { try? $0.get(illustrationAlbumId) }
    }

    func deleteIllustration(withID illustrationID: String) {
        let query = illustrationsTable.filter(illustrationId == illustrationID)
        try? db.run(query.delete())
    }

    // MARK: - Thumbnails (stored within illustrations table)

    func thumbnailCount() -> Int {
        let query = illustrationsTable.filter(illustrationThumbnailData != nil)
        return (try? db.scalar(query.count)) ?? 0
    }

    func deleteAllThumbnails() {
        try? db.run(illustrationsTable.update(illustrationThumbnailData <- nil))
    }

    // MARK: - Delete All

    func deleteAll() {
        try? db.run(illustrationsTable.delete())
        try? db.run(albumsTable.delete())
    }
}
