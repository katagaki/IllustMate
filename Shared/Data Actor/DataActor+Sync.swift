//
//  DataActor+Sync.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//

import Foundation
@preconcurrency import SQLite

enum SyncRecordType {
    static let pic = "Pic"
    static let album = "Album"
    static let library = "Library"
}

/// Sendable snapshot of a library registry entry, exchanged with SyncMate.
struct LibrarySyncSnapshot: Sendable {
    let id: String
    let name: String
    let systemFields: Data?
    let lastModified: Double
}

/// Sendable snapshot of a pic's synced metadata, exchanged with SyncMate.
struct PicSyncSnapshot: Sendable {
    let id: String
    let name: String
    let albumID: String?
    let dateAdded: Double
    let mediaType: Int
    let duration: Double?
    let thumbnail: Data?
    let systemFields: Data?
    let lastModified: Double
}

/// Sendable snapshot of an album's synced metadata.
struct AlbumSyncSnapshot: Sendable {
    let id: String
    let name: String
    let parentAlbumID: String?
    let dateCreated: Double
    let systemFields: Data?
    let lastModified: Double
}

extension DataActor {

    /// Current time as a Unix timestamp, for `last_modified` bookkeeping.
    var syncTimestamp: Double { Date.now.timeIntervalSince1970 }

    /// Records a deletion so it can be propagated to other devices.
    func recordTombstone(id: String, recordType: String) {
        _ = try? database.run(tombstonesTable.insert(or: .replace,
            tombstoneId <- id,
            tombstoneRecordType <- recordType,
            tombstoneDeletedAt <- syncTimestamp
        ))
    }

    func recordTombstones(ids: [String], recordType: String) {
        for id in ids {
            recordTombstone(id: id, recordType: recordType)
        }
    }

    // MARK: - Upload: dirty records + tombstones

    func dirtyAlbumIDs() -> [String] {
        (try? database.prepare(albumsTable.filter(syncDirty == true).select(albumId))
            .map { $0[albumId] }) ?? []
    }

    func dirtyPicIDs() -> [String] {
        (try? database.prepare(picsTable.filter(syncDirty == true).select(picId))
            .map { $0[picId] }) ?? []
    }

    /// Albums never confirmed as synced (no CloudKit system fields). The
    /// consistency pass re-enqueues these so the cloud can't be left missing them.
    func unsyncedAlbumIDs() -> [String] {
        (try? database.prepare(albumsTable.filter(syncCKSystemFields == nil).select(albumId))
            .map { $0[albumId] }) ?? []
    }

    /// Pics never confirmed as synced (no CloudKit system fields).
    func unsyncedPicIDs() -> [String] {
        (try? database.prepare(picsTable.filter(syncCKSystemFields == nil).select(picId))
            .map { $0[picId] }) ?? []
    }

    func pendingTombstones() -> [(id: String, recordType: String)] {
        (try? database.prepare(tombstonesTable)
            .map { (id: $0[tombstoneId], recordType: $0[tombstoneRecordType]) }) ?? []
    }

    func removeTombstone(id: String) {
        _ = try? database.run(tombstonesTable.filter(tombstoneId == id).delete())
    }

    func albumSyncSnapshot(forID id: String) -> AlbumSyncSnapshot? {
        guard let row = try? database.pluck(albumsTable.filter(albumId == id)) else { return nil }
        return AlbumSyncSnapshot(
            id: id,
            name: (try? row.get(albumName)) ?? "",
            parentAlbumID: try? row.get(albumParentId),
            dateCreated: (try? row.get(albumDateCreated)) ?? 0,
            systemFields: try? row.get(syncCKSystemFields),
            lastModified: (try? row.get(syncLastModified)) ?? 0
        )
    }

    func picSyncSnapshot(forID id: String) -> PicSyncSnapshot? {
        guard let row = try? database.pluck(picsTable.filter(picId == id)) else { return nil }
        return PicSyncSnapshot(
            id: id,
            name: (try? row.get(picName)) ?? "",
            albumID: try? row.get(picAlbumId),
            dateAdded: (try? row.get(picDateAdded)) ?? 0,
            mediaType: (try? row.get(picMediaType)) ?? 0,
            duration: try? row.get(picDuration),
            thumbnail: try? row.get(picThumbnailData),
            systemFields: try? row.get(syncCKSystemFields),
            lastModified: (try? row.get(syncLastModified)) ?? 0
        )
    }

    func markAlbumSynced(id: String, systemFields: Data?) {
        _ = try? database.run(albumsTable.filter(albumId == id)
            .update(syncDirty <- false, syncCKSystemFields <- systemFields))
    }

    func markPicSynced(id: String, systemFields: Data?) {
        _ = try? database.run(picsTable.filter(picId == id)
            .update(syncDirty <- false, syncCKSystemFields <- systemFields))
    }

    /// Image pics with a local original that hasn't been mirrored to iCloud Drive.
    func picIDsNeedingOriginalUpload() -> [String] {
        let query = picsTable
            .filter(picMediaType == MediaType.pic.rawValue && picFilePath != nil && syncOriginalSynced == false)
            .select(picId)
        return (try? database.prepare(query).map { $0[picId] }) ?? []
    }

    func markPicOriginalSynced(id: String) {
        _ = try? database.run(picsTable.filter(picId == id).update(syncOriginalSynced <- true))
    }

    // MARK: - Download: apply remote changes

    func applyRemoteAlbum(_ snapshot: AlbumSyncSnapshot) {
        let exists = ((try? database.scalar(albumsTable.filter(albumId == snapshot.id).count)) ?? 0) > 0
        if exists {
            _ = try? database.run(albumsTable.filter(albumId == snapshot.id).update(
                albumName <- snapshot.name,
                albumParentId <- snapshot.parentAlbumID,
                albumDateCreated <- snapshot.dateCreated,
                syncDirty <- false,
                syncCKSystemFields <- snapshot.systemFields,
                syncLastModified <- snapshot.lastModified
            ))
        } else {
            _ = try? database.run(albumsTable.insert(or: .replace,
                albumId <- snapshot.id,
                albumName <- snapshot.name,
                albumCoverPhoto <- nil,
                albumParentId <- snapshot.parentAlbumID,
                albumDateCreated <- snapshot.dateCreated,
                syncDirty <- false,
                syncCKSystemFields <- snapshot.systemFields,
                syncLastModified <- snapshot.lastModified
            ))
        }
    }

    func applyRemotePic(_ snapshot: PicSyncSnapshot) {
        let exists = ((try? database.scalar(picsTable.filter(picId == snapshot.id).count)) ?? 0) > 0
        if exists {
            _ = try? database.run(picsTable.filter(picId == snapshot.id).update(
                picName <- snapshot.name,
                picAlbumId <- snapshot.albumID,
                picDateAdded <- snapshot.dateAdded,
                picMediaType <- snapshot.mediaType,
                picDuration <- snapshot.duration,
                picThumbnailData <- snapshot.thumbnail,
                syncDirty <- false,
                syncCKSystemFields <- snapshot.systemFields,
                syncLastModified <- snapshot.lastModified
            ))
        } else {
            _ = try? database.run(picsTable.insert(or: .replace,
                picId <- snapshot.id,
                picName <- snapshot.name,
                picAlbumId <- snapshot.albumID,
                picDateAdded <- snapshot.dateAdded,
                picThumbnailData <- snapshot.thumbnail,
                picMediaType <- snapshot.mediaType,
                picDuration <- snapshot.duration,
                syncDirty <- false,
                syncCKSystemFields <- snapshot.systemFields,
                syncLastModified <- snapshot.lastModified
            ))
        }
    }

    func removeAlbumForRemoteDelete(id: String) {
        _ = try? database.run(albumsTable.filter(albumId == id).delete())
        _ = try? database.run(preferencesTable.filter(prefAlbumId == id).delete())
    }

    func removePicForRemoteDelete(id: String) {
        let selectQuery = picsTable.filter(picId == id).select(picFilePath)
        if let row = try? database.pluck(selectQuery),
           let path = try? row.get(picFilePath) {
            if isImagePath(path) {
                deleteImageFile(atRelativePath: path)
            } else {
                deleteVideoFile(atRelativePath: path)
            }
        }
        _ = try? database.run(picsTable.filter(picId == id).delete())
    }
}
