//
//  DataActor+Pics.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/02/22.
//

import Foundation
@preconcurrency import SQLite

extension DataActor {
    /// Common columns selected for pic listing queries.
    private var picListColumns: [Expressible] {
        [picId, picName, picAlbumId, picDateAdded, picThumbnailData,
         picMediaType, picDuration, picFilePath]
    }

    /// Common columns selected for skeleton queries (no thumbnail).
    private var picSkeletonColumns: [Expressible] {
        [picId, picName, picAlbumId, picDateAdded, picMediaType, picDuration, picFilePath]
    }

    func pics() throws -> [Pic] {
        let query = picsTable
            .select(picListColumns)
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
            .select(picListColumns)
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
            .select(picSkeletonColumns)
        return try database.prepare(orderedQuery).map { picFrom(row: $0) }
    }

    func picSkeletonsByName(in album: Album?, order: SortOrder) throws -> [Pic] {
        let baseQuery: SQLite.Table
        if let albumID = album?.id {
            baseQuery = picsTable.filter(picAlbumId == albumID)
        } else {
            baseQuery = picsTable.filter(picAlbumId == nil)
        }
        let query = baseQuery.select(picSkeletonColumns)
        let pics = try database.prepare(query).map { picFrom(row: $0) }
        return pics.sorted { lhs, rhs in
            let result = lhs.name.localizedStandardCompare(rhs.name)
            return order == .reverse ? result == .orderedDescending : result == .orderedAscending
        }
    }

    func picCount(in album: Album?) -> Int {
        let query: SQLite.Table
        if let albumID = album?.id {
            query = picsTable.filter(picAlbumId == albumID)
        } else {
            query = picsTable.filter(picAlbumId == nil)
        }
        return (try? database.scalar(query.count)) ?? 0
    }

    func thumbnailData(forPicWithID id: String) -> Data? {
        let query = picsTable
            .filter(picId == id)
            .select(picThumbnailData)
        return try? database.pluck(query).flatMap { try? $0.get(picThumbnailData) }
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
            picThumbnailData <- thumbnailData,
            picMediaType <- MediaType.pic.rawValue
        ))
    }

    func createVideo(
        _ name: String,
        data: Data,
        duration: TimeInterval,
        fileExtension: String,
        inAlbumWithID albumID: String? = nil,
        dateAdded: Date? = nil
    ) async {
        let id = UUID().uuidString
        let now = dateAdded ?? Date.now
        guard let relativePath = saveVideoFile(data, id: id, fileExtension: fileExtension) else {
            return
        }
        let videoURL = videoFileURL(forRelativePath: relativePath)
        let thumbnailData = await Pic.makeVideoThumbnail(videoURL)
        _ = try? database.run(picsTable.insert(
            picId <- id,
            picName <- name,
            picAlbumId <- albumID,
            picDateAdded <- now.timeIntervalSince1970,
            picData <- Data(),
            picThumbnailData <- thumbnailData,
            picMediaType <- MediaType.video.rawValue,
            picDuration <- duration,
            picFilePath <- relativePath
        ))
    }

    func addPics(withIDs picIDs: [String], toAlbumWithID albumID: String) {
        guard !picIDs.isEmpty else { return }
        let query = picsTable.filter(picIDs.contains(picId))
        _ = try? database.run(query.update(picAlbumId <- albumID))
    }

    func addPic(withID picID: String, toAlbumWithID albumID: String) {
        let query = picsTable.filter(picId == picID)
        _ = try? database.run(query.update(picAlbumId <- albumID))
    }

    func removeParentAlbum(forPicsWithIDs picIDs: [String]) {
        guard !picIDs.isEmpty else { return }
        let query = picsTable.filter(picIDs.contains(picId))
        _ = try? database.run(query.update(picAlbumId <- nil))
    }

    func setAsAlbumCover(for picID: String) {
        let data = imageData(forPicWithID: picID) ?? thumbnailData(forPicWithID: picID)
        if let data,
           let albumID = containingAlbumID(forPicWithID: picID) {
            let coverData = Album.makeCover(data)
            let query = albumsTable.filter(albumId == albumID)
            _ = try? database.run(query.update(albumCoverPhoto <- coverData))
        }
    }

    func picName(forPicWithID picID: String) -> String? {
        let query = picsTable
            .filter(picId == picID)
            .select(picName)
        return try? database.pluck(query).map { $0[picName] }
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
        // Delete video file from disk if present
        let selectQuery = picsTable.filter(picId == picID).select(picFilePath)
        if let row = try? database.pluck(selectQuery),
           let path = try? row.get(picFilePath) {
            deleteVideoFile(atRelativePath: path)
        }
        let query = picsTable.filter(picId == picID)
        _ = try? database.run(query.delete())
    }

    func deletePics(withIDs picIDs: [String]) {
        guard !picIDs.isEmpty else { return }
        // Delete video files from disk if present
        let selectQuery = picsTable.filter(picIDs.contains(picId)).select(picFilePath)
        if let rows = try? database.prepare(selectQuery) {
            for row in rows {
                if let path = try? row.get(picFilePath) {
                    deleteVideoFile(atRelativePath: path)
                }
            }
        }
        let query = picsTable.filter(picIDs.contains(picId))
        _ = try? database.run(query.delete())
    }

    /// Returns the file URL for a video pic, or nil if not a video.
    func videoURL(forPicWithID picID: String) -> URL? {
        let query = picsTable.filter(picId == picID).select(picFilePath)
        guard let row = try? database.pluck(query),
              let path = try? row.get(picFilePath) else { return nil }
        return videoFileURL(forRelativePath: path)
    }

    // MARK: - Thumbnails

    func deleteAllThumbnails() {
        _ = try? database.run(picsTable.update(picThumbnailData <- nil))
    }

    // MARK: - Delete All

    func deleteAll() {
        // Remove all video files
        let videosDir = videosDirectoryURL()
        try? FileManager.default.removeItem(at: videosDir)
        _ = try? database.run(picsTable.delete())
        _ = try? database.run(albumsTable.delete())
    }
}
