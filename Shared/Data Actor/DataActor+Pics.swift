//
//  DataActor+Pics.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/02/22.
//

import Foundation
@preconcurrency import SQLite

extension DataActor {
    private var picListColumns: [Expressible] {
        [picId, picName, picAlbumId, picDateAdded, picThumbnailData,
         picMediaType, picDuration, picFilePath]
    }

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
        // Prefer the externalized file; only fall back to the legacy blob when
        // the file is absent (pre-migration row or a failed file write).
        let metaQuery = picsTable
            .filter(picId == id)
            .select(picFilePath, picMediaType)
        if let row = try? database.pluck(metaQuery) {
            let mediaType = (try? row.get(picMediaType)) ?? 0
            if mediaType == MediaType.pic.rawValue,
               let path = try? row.get(picFilePath),
               let data = try? Data(contentsOf: imageFileURL(forRelativePath: path)),
               !data.isEmpty {
                return data
            }
        }
        let blobQuery = picsTable
            .filter(picId == id)
            .select(picData)
        return try? database.pluck(blobQuery).flatMap { try? $0.get(picData) }
    }

    /// Reads the raw stored blob for a pic, bypassing the file fallback.
    /// Used by the blob-externalization migration.
    func rawBlobData(forPicWithID id: String) -> Data? {
        let query = picsTable
            .filter(picId == id)
            .select(picData)
        return try? database.pluck(query).flatMap { try? $0.get(picData) }
    }

    func createPic(_ name: String, data: Data, inAlbumWithID albumID: String? = nil, dateAdded: Date? = nil) {
        let id = UUID().uuidString
        let now = dateAdded ?? Date.now
        let thumbnailData = Pic.makeThumbnail(data)
        // Store the image as a file; only keep the blob as a fallback if the
        // file write fails, so a pic always has its bytes somewhere.
        let relativePath = saveImageFile(data, id: id)
        _ = try? database.run(picsTable.insert(
            picId <- id,
            picName <- name,
            picAlbumId <- albumID,
            picDateAdded <- now.timeIntervalSince1970,
            picData <- relativePath == nil ? data : nil,
            picThumbnailData <- thumbnailData,
            picMediaType <- MediaType.pic.rawValue,
            picFilePath <- relativePath,
            syncDirty <- true,
            syncLastModified <- now.timeIntervalSince1970
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
            picFilePath <- relativePath,
            syncDirty <- true,
            syncLastModified <- now.timeIntervalSince1970
        ))
    }

    func addPics(withIDs picIDs: [String], toAlbumWithID albumID: String) {
        guard !picIDs.isEmpty else { return }
        let query = picsTable.filter(picIDs.contains(picId))
        _ = try? database.run(query.update(
            picAlbumId <- albumID, syncDirty <- true, syncLastModified <- syncTimestamp
        ))
    }

    func addPic(withID picID: String, toAlbumWithID albumID: String) {
        let query = picsTable.filter(picId == picID)
        _ = try? database.run(query.update(
            picAlbumId <- albumID, syncDirty <- true, syncLastModified <- syncTimestamp
        ))
    }

    func removeParentAlbum(forPicsWithIDs picIDs: [String]) {
        guard !picIDs.isEmpty else { return }
        let query = picsTable.filter(picIDs.contains(picId))
        _ = try? database.run(query.update(
            picAlbumId <- nil, syncDirty <- true, syncLastModified <- syncTimestamp
        ))
    }

    func setAsAlbumCover(for picID: String) {
        let data = imageData(forPicWithID: picID) ?? thumbnailData(forPicWithID: picID)
        if let data,
           let albumID = containingAlbumID(forPicWithID: picID) {
            let coverData = Album.makeCover(data)
            let query = albumsTable.filter(albumId == albumID)
            _ = try? database.run(query.update(
                albumCoverPhoto <- coverData, syncDirty <- true, syncLastModified <- syncTimestamp
            ))
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
        _ = try? database.run(query.update(
            picName <- newName, syncDirty <- true, syncLastModified <- syncTimestamp
        ))
    }

    func updateThumbnail(forPicWithID picID: String, thumbnailData: Data?) {
        let query = picsTable.filter(picId == picID)
        _ = try? database.run(query.update(
            picThumbnailData <- thumbnailData, syncDirty <- true, syncLastModified <- syncTimestamp
        ))
    }

    private func containingAlbumID(forPicWithID picID: String) -> String? {
        let query = picsTable
            .filter(picId == picID)
            .select(picAlbumId)
        return try? database.pluck(query).flatMap { try? $0.get(picAlbumId) }
    }

    func deletePic(withID picID: String) {
        let selectQuery = picsTable.filter(picId == picID).select(picFilePath)
        if let row = try? database.pluck(selectQuery),
           let path = try? row.get(picFilePath) {
            deleteMediaFile(atRelativePath: path)
        }
        recordTombstone(id: picID, recordType: SyncRecordType.pic)
        let query = picsTable.filter(picId == picID)
        _ = try? database.run(query.delete())
    }

    func deletePics(withIDs picIDs: [String]) {
        guard !picIDs.isEmpty else { return }
        let selectQuery = picsTable.filter(picIDs.contains(picId)).select(picFilePath)
        if let rows = try? database.prepare(selectQuery) {
            for row in rows {
                if let path = try? row.get(picFilePath) {
                    deleteMediaFile(atRelativePath: path)
                }
            }
        }
        recordTombstones(ids: picIDs, recordType: SyncRecordType.pic)
        let query = picsTable.filter(picIDs.contains(picId))
        _ = try? database.run(query.delete())
    }

    private func deleteMediaFile(atRelativePath path: String) {
        if isImagePath(path) {
            deleteImageFile(atRelativePath: path)
        } else {
            deleteVideoFile(atRelativePath: path)
        }
    }

    /// Local file URL for a video pic, or nil when no local copy exists (e.g. the
    /// original was reclaimed after mirroring to iCloud, or this device only has
    /// the synced metadata). Callers fall back to the iCloud Drive original.
    func videoURL(forPicWithID picID: String) -> URL? {
        let query = picsTable.filter(picId == picID).select(picFilePath)
        guard let row = try? database.pluck(query),
              let path = (try? row.get(picFilePath)) ?? nil else { return nil }
        let url = videoFileURL(forRelativePath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Thumbnails

    func deleteAllThumbnails() {
        _ = try? database.run(picsTable.update(picThumbnailData <- nil))
    }

    // MARK: - Delete All

    func deleteAll() {
        try? FileManager.default.removeItem(at: imagesDirectoryURL())
        try? FileManager.default.removeItem(at: videosDirectoryURL())
        _ = try? database.run(picsTable.delete())
        _ = try? database.run(albumsTable.delete())
    }
}
