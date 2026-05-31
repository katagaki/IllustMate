import Foundation
@preconcurrency import SQLite

enum BackupError: Error {
    case destinationInaccessible
    case insufficientSpace(required: Int64, available: Int64)
    case originalUnavailable
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
        do {
            try await inlineOriginals(intoBackupAt: destinationURL,
                                      originalProvider: originalProvider, progress: progress)
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

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
        notifyLocalMutation()
    }

    // MARK: - Import strategies

    private func importIntoAlbum(_ targetAlbumID: String, from foreignDB: Connection) throws {
        var albumIDMap: [String: String] = [:]
        for foreignAlbum in try foreignDB.prepare(albumsTable) {
            let oldID = (try? foreignAlbum.get(albumId)) ?? UUID().uuidString
            let newID = UUID().uuidString
            albumIDMap[oldID] = newID
            let oldParentID = try? foreignAlbum.get(albumParentId)
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
            if ((try? database.scalar(picsTable.filter(picId == id).count)) ?? 0) > 0 { continue }
            let albumID = try? foreignPic.get(picAlbumId)
            importForeignPic(foreignPic, newID: id, albumID: albumID)
        }
    }

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
