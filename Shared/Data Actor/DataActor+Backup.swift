//
//  DataActor+Backup.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/17.
//

import Foundation
@preconcurrency import SQLite

extension DataActor {

    func backupDatabase(to destinationDirectoryURL: URL, libraryName: String) throws {
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
            // Externalized images live outside the DB, so re-inline them into the
            // copy to produce a self-contained, single-file `.pics` backup.
            inlineImageFiles(intoBackupAt: destinationURL)
        } else {
            throw NSError(domain: "DataActor",
                          code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not access destination folder"])
        }
    }

    /// Writes each externalized image file's bytes back into the backup
    /// database's `data` column (clearing `file_path`), so the resulting `.pics`
    /// is a blob-based, self-contained file that any app version can restore.
    private func inlineImageFiles(intoBackupAt url: URL) {
        guard let backupDB = try? Connection(url.path) else { return }
        let query = picsTable
            .filter(picMediaType == MediaType.pic.rawValue && picFilePath != nil)
            .select(picId, picFilePath)
        var work: [(id: String, path: String)] = []
        if let rows = try? backupDB.prepare(query) {
            for row in rows {
                if let path = try? row.get(picFilePath) {
                    work.append((row[picId], path))
                }
            }
        }
        for item in work {
            guard let blob = try? Data(contentsOf: imageFileURL(forRelativePath: item.path)) else {
                continue
            }
            _ = try? backupDB.run(picsTable.filter(picId == item.id).update(
                picData <- blob,
                picFilePath <- nil
            ))
        }
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

    /// Restores one pic from a backup row into the externalized layout: the blob
    /// is written to an image file (kept inline only if the write fails). Uses
    /// INSERT OR IGNORE so merges skip pics that already exist; for album imports
    /// the IDs are fresh so it never conflicts. Videos are skipped (their files
    /// aren't part of a single-file backup), matching prior behavior.
    private func importForeignPic(_ row: Row, newID: String, albumID: String?) {
        let mediaType = (try? row.get(picMediaType)) ?? 0
        let foreignFilePath = try? row.get(picFilePath)
        if mediaType == MediaType.video.rawValue && foreignFilePath != nil { return }
        guard let blob = try? row.get(picData) else { return }
        let relativePath = saveImageFile(blob, id: newID)
        _ = try? database.run(picsTable.insert(or: .ignore,
            picId <- newID,
            picName <- (try? row.get(picName)) ?? Pic.newFilename(),
            picAlbumId <- albumID,
            picDateAdded <- (try? row.get(picDateAdded)) ?? Date.now.timeIntervalSince1970,
            picData <- relativePath == nil ? blob : nil,
            picThumbnailData <- (try? row.get(picThumbnailData)),
            picMediaType <- mediaType,
            picFilePath <- relativePath
        ))
    }
}
