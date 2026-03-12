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
            albumFrom(row: row, loadChildren: false)
        }
        populateCounts(for: albums)
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
            albumFrom(row: row, loadChildren: false)
        }
        populateCounts(for: albums)
        return sortAlbum(albums, sortedBy: sortType)
    }

    /// Batch-populates childAlbumCount and childPicCount for all albums in one pass.
    private func populateCounts(for albums: [Album]) {
        let ids = albums.map { $0.id }
        guard !ids.isEmpty else { return }

        let bindings: [Binding?] = ids.map { $0 as Binding? }
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")

        // Batch album counts
        var albumCounts: [String: Int] = [:]
        let albumCountSQL = "SELECT parent_album_id, COUNT(*) FROM albums WHERE parent_album_id IN (\(placeholders)) GROUP BY parent_album_id"
        if let stmt = try? database.prepare(albumCountSQL, bindings) {
            for row in stmt {
                if let parentId = row[0] as? String,
                   let count = row[1] as? Int64 {
                    albumCounts[parentId] = Int(count)
                }
            }
        }

        // Batch pic counts
        var picCounts: [String: Int] = [:]
        let picCountSQL = "SELECT containing_album_id, COUNT(*) FROM pics WHERE containing_album_id IN (\(placeholders)) GROUP BY containing_album_id"
        if let stmt = try? database.prepare(picCountSQL, bindings) {
            for row in stmt {
                if let albumId = row[0] as? String,
                   let count = row[1] as? Int64 {
                    picCounts[albumId] = Int(count)
                }
            }
        }

        for album in albums {
            album.childAlbumCount = albumCounts[album.id] ?? 0
            album.childPicCount = picCounts[album.id] ?? 0
        }
    }

    func representativeThumbnails(forAlbumWithID albumID: String, limit: Int = 3) -> [Data] {
        let query = picsTable
            .filter(picAlbumId == albumID)
            .select(picThumbnailData)
            .order(picDateAdded.desc)
            .limit(limit)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { try? $0.get(picThumbnailData) }
    }

    /// Fetches a single representative thumbnail at a given offset (0-indexed),
    /// ordered by most recently added. Used for concurrent per-thumbnail fetching.
    func representativeThumbnail(forAlbumWithID albumID: String, at offset: Int) -> Data? {
        let query = picsTable
            .filter(picAlbumId == albumID)
            .select(picThumbnailData)
            .order(picDateAdded.desc)
            .limit(1, offset: offset)
        guard let row = try? database.pluck(query) else { return nil }
        return try? row.get(picThumbnailData)
    }

    func album(for id: String) -> Album? {
        let query = albumsTable.filter(albumId == id)
        return try? database.pluck(query).map { albumFrom(row: $0, loadChildren: false) }
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

    // MARK: - Search

    func searchAlbums(matching searchText: String, sortedBy sortType: SortType) throws -> [Album] {
        let pattern = "%\(searchText)%"
        let query = albumsTable.filter(albumName.like(pattern, escape: nil))
        let rows = try database.prepare(query)
        let albums = rows.map { row -> Album in
            albumFrom(row: row, loadChildren: false)
        }
        populateCounts(for: albums)
        return sortAlbum(albums, sortedBy: sortType)
    }

    func searchAlbums(
        matching searchText: String, in parentAlbum: Album?, sortedBy sortType: SortType
    ) throws -> [Album] {
        let descendantIDs = descendantAlbumIDs(of: parentAlbum?.id)
        let pattern = "%\(searchText)%"
        let query = albumsTable.filter(
            descendantIDs.contains(albumId) && albumName.like(pattern, escape: nil)
        )
        let rows = try database.prepare(query)
        let albums = rows.map { row -> Album in
            albumFrom(row: row, loadChildren: false)
        }
        populateCounts(for: albums)
        return sortAlbum(albums, sortedBy: sortType)
    }

    private func descendantAlbumIDs(of parentID: String?) -> [String] {
        // Iterative BFS: one query per level instead of one query per node
        let firstQuery: QueryType
        if let parentID {
            firstQuery = albumsTable.filter(albumParentId == parentID).select(albumId)
        } else {
            firstQuery = albumsTable.filter(albumParentId == nil).select(albumId)
        }
        guard let rows = try? database.prepare(firstQuery) else { return [] }
        var currentLevel = rows.compactMap { try? $0.get(albumId) }
        var allIDs = currentLevel

        while !currentLevel.isEmpty {
            let nextQuery = albumsTable
                .filter(currentLevel.contains(albumParentId))
                .select(albumId)
            guard let nextRows = try? database.prepare(nextQuery) else { break }
            currentLevel = nextRows.compactMap { try? $0.get(albumId) }
            allIDs.append(contentsOf: currentLevel)
        }
        return allIDs
    }
}
