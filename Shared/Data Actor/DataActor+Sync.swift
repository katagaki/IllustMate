import Foundation
@preconcurrency import SQLite

enum SyncRecordType {
    static let pic = "Pic"
    static let album = "Album"
    static let library = "Library"
}

extension Notification.Name {
    static let dataActorDidMutateLocally = Notification.Name("DataActorDidMutateLocally")
}

struct LibrarySyncSnapshot: Sendable {
    let id: String
    let name: String
    let systemFields: Data?
    let lastModified: Double
}

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

struct AlbumSyncSnapshot: Sendable {
    let id: String
    let name: String
    let parentAlbumID: String?
    let dateCreated: Double
    let systemFields: Data?
    let lastModified: Double
}

struct OriginalLocation: Sendable {
    let mediaType: MediaType
    let filename: String?
    let localURL: URL?
}

extension DataActor {

    var syncTimestamp: Double { Date.now.timeIntervalSince1970 }

    nonisolated func notifyLocalMutation() {
        NotificationCenter.default.post(name: .dataActorDidMutateLocally, object: collectionID)
    }

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

    func picWasSynced(id: String) -> Bool {
        let query = picsTable.filter(picId == id).select(syncCKSystemFields)
        guard let row = try? database.pluck(query) else { return false }
        return ((try? row.get(syncCKSystemFields)) ?? nil) != nil
    }

    func syncedPicIDs(among ids: [String]) -> [String] {
        guard !ids.isEmpty else { return [] }
        let query = picsTable
            .filter(ids.contains(picId) && syncCKSystemFields != nil)
            .select(picId)
        return (try? database.safeRows(query).map { $0[picId] }) ?? []
    }

    func albumWasSynced(id: String) -> Bool {
        let query = albumsTable.filter(albumId == id).select(syncCKSystemFields)
        guard let row = try? database.pluck(query) else { return false }
        return ((try? row.get(syncCKSystemFields)) ?? nil) != nil
    }

    // MARK: - Upload: dirty records + tombstones

    func dirtyAlbumIDs() -> [String] {
        (try? database.safeRows(albumsTable.filter(syncDirty == true).select(albumId))
            .map { $0[albumId] }) ?? []
    }

    func dirtyPicIDs() -> [String] {
        (try? database.safeRows(picsTable.filter(syncDirty == true).select(picId))
            .map { $0[picId] }) ?? []
    }

    func unsyncedAlbumIDs() -> [String] {
        (try? database.safeRows(albumsTable.filter(syncCKSystemFields == nil).select(albumId))
            .map { $0[albumId] }) ?? []
    }

    func unsyncedPicIDs() -> [String] {
        (try? database.safeRows(picsTable.filter(syncCKSystemFields == nil).select(picId))
            .map { $0[picId] }) ?? []
    }

    func pendingTombstones() -> [(id: String, recordType: String)] {
        (try? database.safeRows(tombstonesTable)
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

    func picIDsNeedingOriginalUpload() -> [String] {
        let query = picsTable
            .filter(picFilePath != nil && syncOriginalSynced == false)
            .select(picId)
        return (try? database.safeRows(query).map { $0[picId] }) ?? []
    }

    func originalLocation(forPicWithID id: String) -> OriginalLocation? {
        let query = picsTable.filter(picId == id).select(picFilePath, picMediaType)
        guard let row = try? database.pluck(query) else { return nil }
        let mediaType = MediaType(rawValue: (try? row.get(picMediaType)) ?? 0) ?? .pic
        let path = (try? row.get(picFilePath)) ?? nil
        switch mediaType {
        case .pic:
            let url = path.map { imageFileURL(forRelativePath: $0) }
            let exists = url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            return OriginalLocation(mediaType: .pic, filename: id, localURL: exists ? url : nil)
        case .video:
            let filename = path.map { ($0 as NSString).lastPathComponent }
            let url = path.map { videoFileURL(forRelativePath: $0) }
            let exists = url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            return OriginalLocation(mediaType: .video, filename: filename, localURL: exists ? url : nil)
        }
    }

    func markPicOriginalSynced(id: String) {
        _ = try? database.run(picsTable.filter(picId == id).update(syncOriginalSynced <- true))
    }

    func resetOriginalSyncState() {
        _ = try? database.run(picsTable.update(syncOriginalSynced <- false))
    }

    func localOriginalPicIDs(inAlbum albumID: String) -> [String] {
        let query = picsTable
            .filter(picAlbumId == albumID && picFilePath != nil)
            .select(picId)
        return (try? database.safeRows(query).map { $0[picId] }) ?? []
    }

    func localOriginalPicIDs() -> [String] {
        let query = picsTable.filter(picFilePath != nil).select(picId)
        return (try? database.safeRows(query).map { $0[picId] }) ?? []
    }

    func allOriginalPicIDs() -> [String] {
        (try? database.safeRows(picsTable.select(picId)).map { $0[picId] }) ?? []
    }

    func allOriginalPicIDs(inAlbum albumID: String) -> [String] {
        let query = picsTable.filter(picAlbumId == albumID).select(picId)
        return (try? database.safeRows(query).map { $0[picId] }) ?? []
    }

    func evictLocalOriginal(picID: String) {
        let query = picsTable.filter(picId == picID).select(picFilePath, picMediaType)
        guard let row = try? database.pluck(query),
              let path = (try? row.get(picFilePath)) ?? nil else { return }
        let mediaType = MediaType(rawValue: (try? row.get(picMediaType)) ?? 0) ?? .pic
        if mediaType == .video {
            deleteVideoFile(atRelativePath: path)
        } else if isImagePath(path) {
            deleteImageFile(atRelativePath: path)
            _ = try? database.run(picsTable.filter(picId == picID).update(picFilePath <- nil))
        }
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
