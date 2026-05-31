import Foundation
@preconcurrency import SQLite

enum BackupError: Error {
    case destinationInaccessible
    case insufficientSpace(required: Int64, available: Int64)
    case originalUnavailable
}

extension DataActor {

    /// A pic in a backup whose original bytes still need to be inlined.
    private struct BackupOriginal {
        let id: String
        let mediaType: Int
        let path: String?
    }

    /// Produces a self-contained `.pics` backup that always includes every
    /// original. `originalProvider`/`sizeProvider` (supplied by the app layer)
    /// fetch a pic's bytes and size from iCloud Drive when the local copy has
    /// been reclaimed. Throws if the destination can't fit the backup or if any
    /// original can't be obtained, so a finished `.pics` is never incomplete.
    func backupDatabase(to destinationDirectoryURL: URL, libraryName: String,
                        originalProvider: (@Sendable (String) async -> Data?)? = nil,
                        sizeProvider: (@Sendable (String) async -> Int64?)? = nil,
                        progress: (@MainActor (Int, Int) -> Void)? = nil) async throws {
        guard destinationDirectoryURL.startAccessingSecurityScopedResource() else {
            throw BackupError.destinationInaccessible
        }
        defer { destinationDirectoryURL.stopAccessingSecurityScopedResource() }

        try await ensureFreeSpace(at: destinationDirectoryURL, sizeProvider: sizeProvider)

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: destinationDirectoryURL.path) {
            try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)
        }
        let destinationURL = destinationDirectoryURL
            .appendingPathComponent(backupFileName(for: libraryName))
        try fileManager.copyItem(at: self.databaseURL, to: destinationURL)
        // Originals live outside the DB (in local files and/or iCloud Drive), so
        // re-inline every image and video into the copy to make a self-contained
        // `.pics`. On any failure the partial file is removed so it can't be
        // mistaken for a complete backup.
        do {
            try await inlineOriginals(intoBackupAt: destinationURL,
                                      originalProvider: originalProvider, progress: progress)
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

    /// Throws `BackupError.insufficientSpace` unless the destination volume can
    /// hold the whole backup, checked before anything is downloaded or copied.
    private func ensureFreeSpace(at directory: URL,
                                 sizeProvider: (@Sendable (String) async -> Int64?)?) async throws {
        let payload = await backupEstimate(sizeProvider: sizeProvider).bytes
        let required = Self.requiredFreeSpace(forBackupPayload: payload)
        let values = try? directory.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey
        ])
        let available = values?.volumeAvailableCapacityForImportantUsage
            ?? values?.volumeAvailableCapacity.map(Int64.init)
            ?? .max
        if available < required {
            throw BackupError.insufficientSpace(required: required, available: available)
        }
    }

    private func backupFileName(for libraryName: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let sanitized = String(libraryName.map { char -> Character in
            let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
            return String(char).unicodeScalars.allSatisfy(invalid.contains) ? "_" : char
        })
        return "Backup-\(sanitized)-\(timestamp).pics"
    }

    /// Writes every pic's original bytes (image or video) into the backup
    /// database's `data` column, so the resulting `.pics` is a blob-based,
    /// self-contained file. Originals are read from the local Images/Videos
    /// cache when present, or downloaded from iCloud Drive when evicted. Image
    /// `file_path`s are cleared (the extension is irrelevant); video `file_path`s
    /// are kept so the original extension survives for restore.
    private func inlineOriginals(intoBackupAt url: URL,
                                 originalProvider: (@Sendable (String) async -> Data?)?,
                                 progress: (@MainActor (Int, Int) -> Void)?) async throws {
        let backupDB = try Connection(url.path)
        let query = picsTable
            .filter(picData == nil)
            .select(picId, picMediaType, picFilePath)
        var work: [BackupOriginal] = []
        for row in try backupDB.prepare(query) {
            work.append(BackupOriginal(id: row[picId],
                                       mediaType: (try? row.get(picMediaType)) ?? 0,
                                       path: (try? row.get(picFilePath)) ?? nil))
        }
        let total = work.count
        await progress?(0, total)
        for (index, item) in work.enumerated() {
            guard let blob = await originalBytes(picID: item.id,
                                                 mediaType: item.mediaType,
                                                 filePath: item.path,
                                                 originalProvider: originalProvider) else {
                throw BackupError.originalUnavailable
            }
            let isVideo = item.mediaType == MediaType.video.rawValue
            try backupDB.run(picsTable.filter(picId == item.id).update(
                picData <- blob,
                picFilePath <- isVideo ? item.path : nil
            ))
            await progress?(index + 1, total)
        }
    }

    /// Returns a pic's original bytes, preferring the local Images/Videos cache
    /// and falling back to `originalProvider` (iCloud Drive) when the original
    /// has been evicted to the cloud.
    private func originalBytes(picID: String, mediaType: Int, filePath: String?,
                               originalProvider: (@Sendable (String) async -> Data?)?) async -> Data? {
        let isVideo = mediaType == MediaType.video.rawValue
        if let filePath {
            let localURL = isVideo
                ? videoFileURL(forRelativePath: filePath)
                : imageFileURL(forRelativePath: filePath)
            if FileManager.default.fileExists(atPath: localURL.path),
               let data = try? Data(contentsOf: localURL) {
                return data
            }
        }
        return await originalProvider?(picID)
    }

    /// Estimated item count and total bytes the finished `.pics` will occupy
    /// (DB metadata plus every original inlined). Drives the free-space check
    /// and the confirmation summary.
    func backupEstimate(sizeProvider: (@Sendable (String) async -> Int64?)?) async -> (count: Int, bytes: Int64) {
        var bytes = fileSize(at: databaseURL)
        var rows: [(id: String, mediaType: Int, path: String?)] = []
        if let prepared = try? database.prepare(picsTable.select(picId, picMediaType, picFilePath)) {
            for row in prepared {
                rows.append((row[picId], (try? row.get(picMediaType)) ?? 0,
                             (try? row.get(picFilePath)) ?? nil))
            }
        }
        for row in rows {
            let isVideo = row.mediaType == MediaType.video.rawValue
            if let path = row.path {
                let localURL = isVideo
                    ? videoFileURL(forRelativePath: path)
                    : imageFileURL(forRelativePath: path)
                if FileManager.default.fileExists(atPath: localURL.path) {
                    bytes += fileSize(at: localURL)
                    continue
                }
            }
            if let size = await sizeProvider?(row.id) { bytes += size }
        }
        return (rows.count, bytes)
    }

    /// Free space needed to safely write a backup whose inlined payload is
    /// `payloadBytes`, including headroom for SQLite write overhead.
    static func requiredFreeSpace(forBackupPayload payloadBytes: Int64) -> Int64 {
        payloadBytes + payloadBytes / 10 + 50_000_000
    }

    private func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    func importFromBackup(at url: URL, targetAlbumID: String?) throws {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let foreignDB = try Connection(url.path)
        if let targetAlbumID {
            try importIntoAlbum(targetAlbumID, from: foreignDB)
        } else {
            try mergeBackup(from: foreignDB)
        }
    }

    // MARK: - Import strategies

    private func importIntoAlbum(_ targetAlbumID: String, from foreignDB: Connection) throws {
        var albumIDMap: [String: String] = [:]
        for foreignAlbum in try foreignDB.prepare(albumsTable) {
            let oldID = (try? foreignAlbum.get(albumId)) ?? UUID().uuidString
            let newID = UUID().uuidString
            albumIDMap[oldID] = newID
            let oldParentID = try? foreignAlbum.get(albumParentId)
            // Top-level albums go under the target album; nested ones are re-mapped next.
            _ = try? database.run(albumsTable.insert(
                albumId <- newID,
                albumName <- (try? foreignAlbum.get(albumName)) ?? "",
                albumCoverPhoto <- (try? foreignAlbum.get(albumCoverPhoto)),
                albumParentId <- oldParentID == nil ? targetAlbumID : nil,
                albumDateCreated <- (try? foreignAlbum.get(albumDateCreated)) ?? Date.now.timeIntervalSince1970
            ))
        }
        for foreignAlbum in try foreignDB.prepare(albumsTable) {
            let oldID = (try? foreignAlbum.get(albumId)) ?? ""
            guard let oldParentID = try? foreignAlbum.get(albumParentId),
                  let newID = albumIDMap[oldID],
                  let newParentID = albumIDMap[oldParentID] else { continue }
            _ = try? database.run(albumsTable.filter(albumId == newID)
                .update(albumParentId <- newParentID))
        }
        for foreignPic in try foreignDB.prepare(picsTable) {
            let oldAlbumID = try? foreignPic.get(picAlbumId)
            let mappedAlbumID = oldAlbumID.flatMap { albumIDMap[$0] } ?? targetAlbumID
            importForeignPic(foreignPic, newID: UUID().uuidString, albumID: mappedAlbumID)
        }
    }

    private func mergeBackup(from foreignDB: Connection) throws {
        for foreignAlbum in try foreignDB.prepare(albumsTable) {
            _ = try? database.run(albumsTable.insert(or: .ignore,
                albumId <- (try? foreignAlbum.get(albumId)) ?? UUID().uuidString,
                albumName <- (try? foreignAlbum.get(albumName)) ?? "",
                albumCoverPhoto <- (try? foreignAlbum.get(albumCoverPhoto)),
                albumParentId <- (try? foreignAlbum.get(albumParentId)),
                albumDateCreated <- (try? foreignAlbum.get(albumDateCreated)) ?? Date.now.timeIntervalSince1970
            ))
        }
        for foreignPic in try foreignDB.prepare(picsTable) {
            let id = (try? foreignPic.get(picId)) ?? UUID().uuidString
            let albumID = try? foreignPic.get(picAlbumId)
            importForeignPic(foreignPic, newID: id, albumID: albumID)
        }
    }

    /// Restores one pic from a backup row into the externalized layout: the
    /// inlined blob is written out to an image or video file (kept inline only
    /// if the write fails). Video originals are reconstructed using the
    /// extension carried in the backup's `file_path`. Uses INSERT OR IGNORE so
    /// merges skip pics that already exist; for album imports the IDs are fresh
    /// so it never conflicts. Rows without inlined bytes (e.g. videos from
    /// older backups that excluded them) are skipped.
    private func importForeignPic(_ row: Row, newID: String, albumID: String?) {
        let mediaType = (try? row.get(picMediaType)) ?? 0
        let foreignFilePath = try? row.get(picFilePath)
        guard let blob = try? row.get(picData) else { return }
        let relativePath: String?
        if mediaType == MediaType.video.rawValue {
            let ext = foreignFilePath.flatMap { ($0 as NSString).pathExtension }
            relativePath = saveVideoFile(blob, id: newID,
                                         fileExtension: (ext?.isEmpty == false ? ext : nil) ?? "mov")
        } else {
            relativePath = saveImageFile(blob, id: newID)
        }
        _ = try? database.run(picsTable.insert(or: .ignore,
            picId <- newID,
            picName <- (try? row.get(picName)) ?? Pic.newFilename(),
            picAlbumId <- albumID,
            picDateAdded <- (try? row.get(picDateAdded)) ?? Date.now.timeIntervalSince1970,
            picData <- relativePath == nil ? blob : nil,
            picThumbnailData <- (try? row.get(picThumbnailData)),
            picMediaType <- mediaType,
            picDuration <- (try? row.get(picDuration)) ?? nil,
            picFilePath <- relativePath
        ))
    }
}
