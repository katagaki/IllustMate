//
//  DataActor+Illustrations.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2026/02/22.
//

import Foundation
@preconcurrency import SQLite

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

    func createIllustration(_ name: String, data: Data, inAlbumWithID albumID: String? = nil, dateAdded: Date? = nil) {
        let id = UUID().uuidString
        let now = dateAdded ?? Date.now
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
