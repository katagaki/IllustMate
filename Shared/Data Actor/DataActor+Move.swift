import Foundation
@preconcurrency import SQLite

struct AlbumMoveRecord: Sendable {
    let id: String
    let name: String
    let coverPhoto: Data?
    let parentAlbumID: String?
    let dateCreated: Double
}

struct PicMoveRecord: Sendable {
    let id: String
    let name: String
    let albumID: String?
    let dateAdded: Double
    let thumbnail: Data?
    let mediaType: Int
    let duration: Double?
    let filePath: String?

    var resolvedMediaType: MediaType { MediaType(rawValue: mediaType) ?? .pic }
}

extension DataActor {

    // MARK: - Collision checks

    func existingAlbumIDs(among ids: [String]) -> [String] {
        guard !ids.isEmpty else { return [] }
        let query = albumsTable.filter(ids.contains(albumId)).select(albumId)
        return (try? database.safeRows(query).map { $0[albumId] }) ?? []
    }

    func existingPicIDs(among ids: [String]) -> [String] {
        guard !ids.isEmpty else { return [] }
        let query = picsTable.filter(ids.contains(picId)).select(picId)
        return (try? database.safeRows(query).map { $0[picId] }) ?? []
    }

    // MARK: - Subtree collection

    func collectSubtree(forAlbumID albumID: String) -> (albumIDs: [String], picIDs: [String]) {
        var albumIDs = [albumID]
        var queue = [albumID]
        while let current = queue.popLast() {
            let childQuery = albumsTable.filter(albumParentId == current).select(albumId)
            if let rows = try? database.safeRows(childQuery) {
                for row in rows {
                    if let childID = try? row.get(albumId) {
                        albumIDs.append(childID)
                        queue.append(childID)
                    }
                }
            }
        }
        var picIDs: [String] = []
        let picsQuery = picsTable.filter(albumIDs.contains(picAlbumId)).select(picId)
        if let rows = try? database.safeRows(picsQuery) {
            for row in rows {
                if let id = try? row.get(picId) { picIDs.append(id) }
            }
        }
        return (albumIDs, picIDs)
    }

    // MARK: - Move-record reads

    func albumRecordForMove(id: String) -> AlbumMoveRecord? {
        guard let row = try? database.pluck(albumsTable.filter(albumId == id)) else { return nil }
        return AlbumMoveRecord(
            id: id,
            name: (try? row.get(albumName)) ?? "",
            coverPhoto: (try? row.get(albumCoverPhoto)) ?? nil,
            parentAlbumID: (try? row.get(albumParentId)) ?? nil,
            dateCreated: (try? row.get(albumDateCreated)) ?? 0
        )
    }

    func picRecordForMove(id: String) -> PicMoveRecord? {
        guard let row = try? database.pluck(picsTable.filter(picId == id)) else { return nil }
        return PicMoveRecord(
            id: id,
            name: (try? row.get(picName)) ?? "",
            albumID: (try? row.get(picAlbumId)) ?? nil,
            dateAdded: (try? row.get(picDateAdded)) ?? 0,
            thumbnail: (try? row.get(picThumbnailData)) ?? nil,
            mediaType: (try? row.get(picMediaType)) ?? 0,
            duration: (try? row.get(picDuration)) ?? nil,
            filePath: (try? row.get(picFilePath)) ?? nil
        )
    }

    func storedPreferences(forAlbumWithID albumID: String) -> AlbumPreferences? {
        let query = preferencesTable.filter(prefAlbumId == albumID)
        guard let row = try? database.pluck(query) else { return nil }
        return AlbumPreferences(
            albumID: (try? row.get(prefAlbumId)) ?? albumID,
            albumSort: (try? row.get(prefAlbumSort)) ?? AlbumPreferences.defaults.albumSort,
            albumViewStyle: (try? row.get(prefAlbumViewStyle)) ?? AlbumPreferences.defaults.albumViewStyle,
            albumColumnCount: (try? row.get(prefAlbumColumnCount)) ?? AlbumPreferences.defaults.albumColumnCount,
            picSort: (try? row.get(prefPicSort)) ?? AlbumPreferences.defaults.picSort,
            picColumnCount: (try? row.get(prefPicColumnCount)) ?? AlbumPreferences.defaults.picColumnCount,
            hideSectionHeaders: (try? row.get(prefHideSectionHeaders)) ?? AlbumPreferences.defaults.hideSectionHeaders
        )
    }

    // MARK: - Move-record inserts (explicit IDs, new sync zone)

    func insertMovedAlbum(_ record: AlbumMoveRecord, parentAlbumID newParentID: String?) {
        _ = try? database.run(albumsTable.insert(
            albumId <- record.id,
            albumName <- record.name,
            albumCoverPhoto <- record.coverPhoto,
            albumParentId <- newParentID,
            albumDateCreated <- record.dateCreated,
            syncDirty <- true,
            syncLastModified <- syncTimestamp
        ))
    }

    func insertMovedPic(_ record: PicMoveRecord, albumID newAlbumID: String?,
                        filePath: String?, originalSynced: Bool) {
        _ = try? database.run(picsTable.insert(
            picId <- record.id,
            picName <- record.name,
            picAlbumId <- newAlbumID,
            picDateAdded <- record.dateAdded,
            picThumbnailData <- record.thumbnail,
            picMediaType <- record.mediaType,
            picDuration <- record.duration,
            picFilePath <- filePath,
            syncDirty <- true,
            syncOriginalSynced <- originalSynced,
            syncLastModified <- syncTimestamp
        ))
    }

    // MARK: - Local file adoption (copy an original into this library's store)

    func adoptImageFile(from sourceURL: URL, id: String) -> String? {
        ensureImagesDirectoryExists()
        let relativePath = "\(Self.imagesDirectoryName)/\(id)"
        let destinationURL = imageFileURL(forRelativePath: relativePath)
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return relativePath
        } catch {
            debugPrint("Failed to adopt image file: \(error)")
            return nil
        }
    }

    func adoptVideoFile(from sourceURL: URL, id: String, fileExtension: String) -> String? {
        ensureVideosDirectoryExists()
        let filename = "\(id).\(fileExtension)"
        let relativePath = "\(Self.videosDirectoryName)/\(filename)"
        let destinationURL = videoFileURL(forRelativePath: relativePath)
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return relativePath
        } catch {
            debugPrint("Failed to adopt video file: \(error)")
            return nil
        }
    }

    func deleteAdoptedFile(atRelativePath path: String) {
        if isImagePath(path) {
            deleteImageFile(atRelativePath: path)
        } else {
            deleteVideoFile(atRelativePath: path)
        }
    }
}
