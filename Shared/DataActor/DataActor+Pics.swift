//
//  DataActor+Pics.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2026/02/22.
//

import Foundation
@preconcurrency import SQLite

extension DataActor {
    func pics() throws -> [Pic] {
        let query = picsTable
            .select(picId, picName, picAlbumId,
                    picDateAdded, picThumbnailData)
            .order(picDateAdded.desc)
        return try database.prepare(query).map { picFrom(row: $0) }
    }

    func pics(in album: Album?, order: SortOrder) throws -> [Pic] {
        let baseQuery: SQLite.Table
        if let albumID = album?.id {
            baseQuery = picsTable.filter(picAlbumId == albumID)
        } else {
            baseQuery = picsTable.filter(picAlbumId == nil)
        }
        let orderedQuery = (order == .reverse ? baseQuery.order(picDateAdded.desc) :
                                                baseQuery.order(picDateAdded.asc))
            .select(picId, picName, picAlbumId,
                    picDateAdded, picThumbnailData)
        return try database.prepare(orderedQuery).map { picFrom(row: $0) }
    }

    func picSkeletons(in album: Album?, order: SortOrder) throws -> [Pic] {
        let baseQuery: SQLite.Table
        if let albumID = album?.id {
            baseQuery = picsTable.filter(picAlbumId == albumID)
        } else {
            baseQuery = picsTable.filter(picAlbumId == nil)
        }
        let orderedQuery = (order == .reverse ? baseQuery.order(picDateAdded.desc) :
                                                baseQuery.order(picDateAdded.asc))
            .select(picId, picName, picAlbumId,
                    picDateAdded)
        return try database.prepare(orderedQuery).map { picFrom(row: $0) }
    }

    func thumbnailData(forPicWithID id: String) -> Data? {
        let query = picsTable
            .filter(picId == id)
            .select(picThumbnailData)
        return try? database.pluck(query).flatMap { try? $0.get(picThumbnailData) }
    }

    func pic(for id: String) -> Pic? {
        let query = picsTable
            .filter(picId == id)
            .select(picId, picName, picAlbumId,
                    picDateAdded, picThumbnailData)
        return try? database.pluck(query).map { picFrom(row: $0) }
    }

    func imageData(forPicWithID id: String) -> Data? {
        let query = picsTable
            .filter(picId == id)
            .select(picData)
        return try? database.pluck(query).flatMap { try? $0.get(picData) }
    }

    func createPic(_ name: String, data: Data, inAlbumWithID albumID: String? = nil, dateAdded: Date? = nil) {
        let id = UUID().uuidString
        let now = dateAdded ?? Date.now
        let thumbnailData = Pic.makeThumbnail(data)
        _ = try? database.run(picsTable.insert(
            picId <- id,
            picName <- name,
            picAlbumId <- albumID,
            picDateAdded <- now.timeIntervalSince1970,
            picData <- data,
            picThumbnailData <- thumbnailData
        ))
    }

    func addPics(withIDs picIDs: [String], toAlbumWithID albumID: String) {
        for picID in picIDs {
            let query = picsTable.filter(picId == picID)
            _ = try? database.run(query.update(picAlbumId <- albumID))
        }
    }

    func addPic(withID picID: String, toAlbumWithID albumID: String) {
        let query = picsTable.filter(picId == picID)
        _ = try? database.run(query.update(picAlbumId <- albumID))
    }

    func removeParentAlbum(forPicWithID picID: String) {
        let query = picsTable.filter(picId == picID)
        _ = try? database.run(query.update(picAlbumId <- nil))
    }

    func removeParentAlbum(forPicsWithIDs picIDs: [String]) {
        for picID in picIDs {
            let query = picsTable.filter(picId == picID)
            _ = try? database.run(query.update(picAlbumId <- nil))
        }
    }

    func setAsAlbumCover(for picID: String) {
        if let data = imageData(forPicWithID: picID),
           let albumID = containingAlbumID(forPicWithID: picID) {
            let coverData = Album.makeCover(data)
            let query = albumsTable.filter(albumId == albumID)
            _ = try? database.run(query.update(albumCoverPhoto <- coverData))
        }
    }

    func renamePic(withID picID: String, to newName: String) {
        let query = picsTable.filter(picId == picID)
        _ = try? database.run(query.update(picName <- newName))
    }

    func updateThumbnail(forPicWithID picID: String, thumbnailData: Data?) {
        let query = picsTable.filter(picId == picID)
        _ = try? database.run(query.update(picThumbnailData <- thumbnailData))
    }

    private func containingAlbumID(forPicWithID picID: String) -> String? {
        let query = picsTable
            .filter(picId == picID)
            .select(picAlbumId)
        return try? database.pluck(query).flatMap { try? $0.get(picAlbumId) }
    }

    func deletePic(withID picID: String) {
        let query = picsTable.filter(picId == picID)
        _ = try? database.run(query.delete())
    }

    // MARK: - Thumbnails (stored within pics table)

    func thumbnailCount() -> Int {
        let query = picsTable.filter(picThumbnailData != nil)
        return (try? database.scalar(query.count)) ?? 0
    }

    func deleteAllThumbnails() {
        _ = try? database.run(picsTable.update(picThumbnailData <- nil))
    }

    // MARK: - Delete All

    func deleteAll() {
        _ = try? database.run(picsTable.delete())
        _ = try? database.run(albumsTable.delete())
    }
}
