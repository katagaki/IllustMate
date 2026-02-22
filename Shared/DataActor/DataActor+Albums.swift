//
//  DataActor+Albums.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2026/02/22.
//

import Foundation
@preconcurrency import SQLite

extension DataActor {
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

    func deleteAlbumCascade(withID albumID: String) {
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

    func parentAlbumID(forAlbumWithID albumID: String) -> String? {
        let query = albumsTable.filter(albumId == albumID).select(albumParentId)
        return try? database.pluck(query).flatMap { try? $0.get(albumParentId) }
    }
}
