import Foundation
@preconcurrency import SQLite

enum BackupError: Error {
    case destinationInaccessible
    case insufficientSpace(required: Int64, available: Int64)
    case originalUnavailable
    case sourceUnreadable
    case nothingRestored
}

extension DataActor {

    private struct BackupOriginal {
        let id: String
        let mediaType: Int
        let path: String?
    }

    func backupDatabase(to destinationDirectoryURL: URL, libraryName: String,
                        originalProvider: (@Sendable (String) async -> Data?)? = nil,
                        sizeProvider: (@Sendable (String) async -> Int64?)? = nil,
                        prefetch: (@Sendable ([String]) async -> Void)? = nil,
                        progress: (@MainActor (Int, Int) -> Void)? = nil) async throws -> Int {
        guard destinationDirectoryURL.startAccessingSecurityScopedResource() else {
            throw BackupError.destinationInaccessible
        }
        defer { destinationDirectoryURL.stopAccessingSecurityScopedResource() }

        try await ensureFreeSpace(at: destinationDirectoryURL, sizeProvider: sizeProvider)

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: destinationDirectoryURL.path) {
            try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)
        }
        let destinationURL = Self.uniqueURL(
            in: destinationDirectoryURL, fileName: backupFileName(for: libraryName)
        )
        try snapshotDatabase(to: destinationURL)
        do {
            return try await inlineOriginals(intoBackupAt: destinationURL,
                                             originalProvider: originalProvider,
                                             prefetch: prefetch, progress: progress)
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

    private func snapshotDatabase(to url: URL) throws {
        // The database runs in WAL mode, so copying Collection.db alone leaves behind
        // every change still sitting in the -wal sidecar. VACUUM INTO writes a single
        // self-contained file holding the full committed state instead.
        let escapedPath = url.path.replacingOccurrences(of: "'", with: "''")
        try database.execute("VACUUM INTO '\(escapedPath)'")
    }

    static func uniqueURL(in directory: URL, fileName: String) -> URL {
        let fileManager = FileManager.default
        var candidate = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }
        let stem = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var suffix = 2
        repeat {
            let name = ext.isEmpty ? "\(stem) \(suffix)" : "\(stem) \(suffix).\(ext)"
            candidate = directory.appendingPathComponent(name)
            suffix += 1
        } while fileManager.fileExists(atPath: candidate.path)
        return candidate
    }

    func ensureFreeSpace(at directory: URL,
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

    func backupFileName(for libraryName: String, fileExtension: String = "pics") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let sanitized = String(libraryName.map { char -> Character in
            let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
            return String(char).unicodeScalars.allSatisfy(invalid.contains) ? "_" : char
        })
        return "Backup-\(sanitized)-\(timestamp).\(fileExtension)"
    }

    private func inlineOriginals(intoBackupAt url: URL,
                                 originalProvider: (@Sendable (String) async -> Data?)?,
                                 prefetch: (@Sendable ([String]) async -> Void)?,
                                 progress: (@MainActor (Int, Int) -> Void)?) async throws -> Int {
        let backupDB = try Connection(url.path)
        _ = try? backupDB.execute("ALTER TABLE \"pics\" ADD COLUMN \"data\" BLOB")
        let query = picsTable
            .filter(picData == nil)
            .select(picId, picMediaType, picFilePath)
        var work: [BackupOriginal] = []
        for row in try backupDB.safeRows(query) {
            work.append(BackupOriginal(id: row[picId],
                                       mediaType: (try? row.get(picMediaType)) ?? 0,
                                       path: (try? row.get(picFilePath)) ?? nil))
        }
        let total = work.count
        var missing = 0
        await progress?(0, total)
        // Every cloud-only original is requested up front so iCloud downloads them in
        // parallel; waiting on them one at a time means each starts from cold and the
        // whole backup fails together when the first ones time out.
        await prefetch?(work.filter { !hasLocalOriginal($0) }.map(\.id))
        for (index, item) in work.enumerated() {
            guard let blob = await originalBytes(picID: item.id,
                                                 mediaType: item.mediaType,
                                                 filePath: item.path,
                                                 originalProvider: originalProvider) else {
                missing += 1
                await progress?(index + 1, total)
                continue
            }
            let isVideo = item.mediaType == MediaType.video.rawValue
            try backupDB.run(picsTable.filter(picId == item.id).update(
                picData <- blob,
                picFilePath <- isVideo ? item.path : nil
            ))
            await progress?(index + 1, total)
        }
        guard total == 0 || missing < total else { throw BackupError.originalUnavailable }
        return missing
    }

    private func hasLocalOriginal(_ item: BackupOriginal) -> Bool {
        guard let path = item.path else { return false }
        let localURL = item.mediaType == MediaType.video.rawValue
            ? videoFileURL(forRelativePath: path)
            : imageFileURL(forRelativePath: path)
        return FileManager.default.fileExists(atPath: localURL.path)
    }

    func originalBytes(picID: String, mediaType: Int, filePath: String?,
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

    func backupEstimate(sizeProvider: (@Sendable (String) async -> Int64?)?) async -> (count: Int, bytes: Int64) {
        var bytes = fileSize(at: databaseURL)
        var rows: [(id: String, mediaType: Int, path: String?)] = []
        if let prepared = try? database.safeRows(picsTable.select(picId, picMediaType, picFilePath)) {
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

    static func requiredFreeSpace(forBackupPayload payloadBytes: Int64) -> Int64 {
        payloadBytes + payloadBytes / 10 + 50_000_000
    }

    func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    @discardableResult
    func importFromBackup(at url: URL, targetAlbumID: String?) throws -> Int {
        // A backup the system hands over by copying it into the app (anything not
        // opened in place) is readable but not security scoped, and asking to access
        // it reports false — treating that as fatal made every such restore a no-op.
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw BackupError.sourceUnreadable
        }
        let foreignDB = try Connection(url.path)
        let imported: Int
        if let targetAlbumID {
            imported = try importIntoAlbum(targetAlbumID, from: foreignDB)
        } else {
            imported = try mergeBackup(from: foreignDB)
        }
        notifyLocalMutation()
        guard imported > 0 else { throw BackupError.nothingRestored }
        return imported
    }

    // MARK: - Import strategies

    private func importIntoAlbum(_ targetAlbumID: String, from foreignDB: Connection) throws -> Int {
        var imported = 0
        var albumIDMap: [String: String] = [:]
        for foreignAlbum in try foreignDB.safeRows(albumsTable) {
            let oldID = (try? foreignAlbum.get(albumId)) ?? UUID().uuidString
            let newID = UUID().uuidString
            albumIDMap[oldID] = newID
            let oldParentID = try? foreignAlbum.get(albumParentId)
            let insert = albumsTable.insert(
                albumId <- newID,
                albumName <- (try? foreignAlbum.get(albumName)) ?? "",
                albumCoverPhoto <- (try? foreignAlbum.get(albumCoverPhoto)),
                albumParentId <- oldParentID == nil ? targetAlbumID : nil,
                albumDateCreated <- (try? foreignAlbum.get(albumDateCreated)) ?? Date.now.timeIntervalSince1970
            )
            if (try? database.run(insert)) != nil { imported += 1 }
        }
        for foreignAlbum in try foreignDB.safeRows(albumsTable) {
            let oldID = (try? foreignAlbum.get(albumId)) ?? ""
            guard let oldParentID = try? foreignAlbum.get(albumParentId),
                  let newID = albumIDMap[oldID],
                  let newParentID = albumIDMap[oldParentID] else { continue }
            _ = try? database.run(albumsTable.filter(albumId == newID)
                .update(albumParentId <- newParentID))
        }
        for foreignPic in try foreignDB.safeRows(picsTable) {
            let oldAlbumID = try? foreignPic.get(picAlbumId)
            let mappedAlbumID = oldAlbumID.flatMap { albumIDMap[$0] } ?? targetAlbumID
            if importForeignPic(foreignPic, newID: UUID().uuidString, albumID: mappedAlbumID) {
                imported += 1
            }
        }
        return imported
    }

    private func mergeBackup(from foreignDB: Connection) throws -> Int {
        var imported = 0
        for foreignAlbum in try foreignDB.safeRows(albumsTable) {
            let insert = albumsTable.insert(or: .ignore,
                albumId <- (try? foreignAlbum.get(albumId)) ?? UUID().uuidString,
                albumName <- (try? foreignAlbum.get(albumName)) ?? "",
                albumCoverPhoto <- (try? foreignAlbum.get(albumCoverPhoto)),
                albumParentId <- (try? foreignAlbum.get(albumParentId)),
                albumDateCreated <- (try? foreignAlbum.get(albumDateCreated)) ?? Date.now.timeIntervalSince1970
            )
            if (try? database.run(insert)) != nil { imported += 1 }
        }
        for foreignPic in try foreignDB.safeRows(picsTable) {
            let id = (try? foreignPic.get(picId)) ?? UUID().uuidString
            if ((try? database.scalar(picsTable.filter(picId == id).count)) ?? 0) > 0 { continue }
            let albumID = try? foreignPic.get(picAlbumId)
            if importForeignPic(foreignPic, newID: id, albumID: albumID) { imported += 1 }
        }
        return imported
    }

    @discardableResult
    private func importForeignPic(_ row: Row, newID: String, albumID: String?) -> Bool {
        let mediaType = (try? row.get(picMediaType)) ?? 0
        let foreignFilePath = try? row.get(picFilePath)
        guard let blob = try? row.get(picData) else { return false }
        let relativePath: String?
        if mediaType == MediaType.video.rawValue {
            let ext = foreignFilePath.flatMap { ($0 as NSString).pathExtension }
            relativePath = saveVideoFile(blob, id: newID,
                                         fileExtension: (ext?.isEmpty == false ? ext : nil) ?? "mov")
        } else {
            relativePath = saveImageFile(blob, id: newID)
        }
        guard let relativePath else { return false }
        let insert = picsTable.insert(or: .ignore,
            picId <- newID,
            picName <- (try? row.get(picName)) ?? Pic.newFilename(),
            picAlbumId <- albumID,
            picDateAdded <- (try? row.get(picDateAdded)) ?? Date.now.timeIntervalSince1970,
            picThumbnailData <- (try? row.get(picThumbnailData)),
            picMediaType <- mediaType,
            picDuration <- (try? row.get(picDuration)) ?? nil,
            picFilePath <- relativePath
        )
        guard (try? database.run(insert)) != nil else {
            deleteStoredFile(atRelativePath: relativePath, isVideo: mediaType == MediaType.video.rawValue)
            return false
        }
        return true
    }

    private func deleteStoredFile(atRelativePath path: String, isVideo: Bool) {
        if isVideo {
            deleteVideoFile(atRelativePath: path)
        } else {
            deleteImageFile(atRelativePath: path)
        }
    }
}
