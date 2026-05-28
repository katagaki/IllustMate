//
//  DataActor+Backup.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/17.
//

import Foundation
@preconcurrency import SQLite

extension DataActor {

    /// A pic in a backup whose original bytes still need to be inlined.
    private struct BackupOriginal {
        let id: String
        let mediaType: Int
        let path: String?
    }

    /// Produces a self-contained `.pics` backup. `originalProvider` (supplied by
    /// the app layer) fetches a pic's original bytes from iCloud Drive when the
    /// local copy has been evicted; pass `nil` to back up only what's local.
    func backupDatabase(to destinationDirectoryURL: URL, libraryName: String,
                        originalProvider: (@Sendable (String) async -> Data?)? = nil) async throws {
        if destinationDirectoryURL.startAccessingSecurityScopedResource() {
            defer { destinationDirectoryURL.stopAccessingSecurityScopedResource() }
            let fileManager = FileManager.default
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let sanitizedName = libraryName.map { char -> Character in
                let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
                if String(char).unicodeScalars.allSatisfy({ invalidChars.contains($0) }) {
                    return "_"
                }
                return char
            }
            let backupFileName = "Backup-\(String(sanitizedName))-\(timestamp).pics"

            if !fileManager.fileExists(atPath: destinationDirectoryURL.path) {
                try fileManager.createDirectory(
                    at: destinationDirectoryURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            let destinationURL = destinationDirectoryURL.appendingPathComponent(backupFileName)
            try fileManager.copyItem(at: self.databaseURL, to: destinationURL)
            // Originals live outside the DB (in local files and/or iCloud Drive),
            // so re-inline every image and video into the copy to produce a
            // self-contained, single-file `.pics` backup.
            await inlineOriginals(intoBackupAt: destinationURL, originalProvider: originalProvider)
        } else {
            throw NSError(domain: "DataActor",
                          code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not access destination folder"])
        }
    }

    /// Writes every pic's original bytes (image or video) into the backup
    /// database's `data` column, so the resulting `.pics` is a blob-based,
    /// self-contained file. Originals are read from the local Images/Videos
    /// cache when present, or downloaded from iCloud Drive when evicted. Image
    /// `file_path`s are cleared (the extension is irrelevant); video `file_path`s
    /// are kept so the original extension survives for restore.
    private func inlineOriginals(intoBackupAt url: URL,
                                 originalProvider: (@Sendable (String) async -> Data?)?) async {
        guard let backupDB = try? Connection(url.path) else { return }
        let query = picsTable
            .filter(picData == nil)
            .select(picId, picMediaType, picFilePath)
        var work: [BackupOriginal] = []
        if let rows = try? backupDB.prepare(query) {
            for row in rows {
                work.append(BackupOriginal(id: row[picId],
                                           mediaType: (try? row.get(picMediaType)) ?? 0,
                                           path: (try? row.get(picFilePath)) ?? nil))
            }
        }
        for item in work {
            guard let blob = await originalBytes(picID: item.id,
                                                 mediaType: item.mediaType,
                                                 filePath: item.path,
                                                 originalProvider: originalProvider) else {
                continue
            }
            let isVideo = item.mediaType == MediaType.video.rawValue
            _ = try? backupDB.run(picsTable.filter(picId == item.id).update(
                picData <- blob,
                picFilePath <- isVideo ? item.path : nil
            ))
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
