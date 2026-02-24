//
//  DataActor+Albums.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/02/22.
//

import Foundation
@preconcurrency import SQLite

extension DataActor {
    func albumsWithCounts(sortedBy sortType: SortType) throws -> [Album] {
        let rows = try database.prepare(albumsTable)
        let albums = rows.map { row -> Album in
            let album = albumFrom(row: row, loadChildren: false)
            album.childAlbumCount = albumCount(forAlbumWithID: album.id)
            album.childPicCount = picCount(forAlbumWithID: album.id)
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
            album.childPicCount = picCount(forAlbumWithID: album.id)
            return album
        }
        return sortAlbum(albums, sortedBy: sortType)
    }

    func representativeThumbnails(forAlbumWithID albumID: String, limit: Int = 3) -> [Data] {
        let query = picsTable
            .filter(picAlbumId == albumID)
            .select(picId)
            .order(picDateAdded.asc)
            .limit(limit)
        guard let rows = try? database.prepare(query) else { return [] }

        let ids = rows.compactMap { try? $0.get(picId) }
        var thumbnails: [Data] = []
        for id in ids {
            if let thumbData = thumbnailData(forPicWithID: id) {
                thumbnails.append(thumbData)
            }
        }
        return thumbnails
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
                $0.albumCount() + $0.picCount() <
                    $1.albumCount() + $1.picCount()
            })
        case .sizeDescending:
            return albums.sorted(by: {
                $0.albumCount() + $0.picCount() >
                $1.albumCount() + $1.picCount()
            })
        }
    }

    func albumCount(forAlbumWithID id: String) -> Int {
        let query = albumsTable.filter(albumParentId == id)
        return (try? database.scalar(query.count)) ?? 0
    }

    func picCount() -> Int {
        return (try? database.scalar(picsTable.count)) ?? 0
    }

    func picCount(forAlbumWithID id: String) -> Int {
        let query = picsTable.filter(picAlbumId == id)
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

        // Move direct pics to parent album, or orphan them
        let illustQuery = picsTable.filter(picAlbumId == albumID)
        if let parentID = parentID {
            _ = try? database.run(illustQuery.update(picAlbumId <- parentID))
        } else {
            _ = try? database.run(illustQuery.update(picAlbumId <- nil))
        }

        // Recursively delete child albums
        deleteAlbumCascade(withID: albumID)
    }

    func deleteAlbumCascade(withID albumID: String) {
        // Orphan all pics in this album
        let illustQuery = picsTable.filter(picAlbumId == albumID)
        _ = try? database.run(illustQuery.update(picAlbumId <- nil))

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
