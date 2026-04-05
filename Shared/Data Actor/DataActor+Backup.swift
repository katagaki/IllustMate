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
        } else {
            throw NSError(domain: "DataActor",
                          code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not access destination folder"])
        }
    }

    // swiftlint:disable:next function_body_length
    func importFromBackup(at url: URL, targetAlbumID: String?) throws {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let foreignDB = try Connection(url.path)

        if let targetAlbumID {
            // Build a mapping from old album IDs to new album IDs
            var albumIDMap: [String: String] = [:]

            // Import albums, re-parenting top-level albums under the target album
            let foreignAlbums = try foreignDB.prepare(albumsTable)
            for foreignAlbum in foreignAlbums {
                let oldID = (try? foreignAlbum.get(albumId)) ?? UUID().uuidString
                let newID = UUID().uuidString
                albumIDMap[oldID] = newID

                let oldParentID = try? foreignAlbum.get(albumParentId)
                // Top-level albums (no parent) go under the target album
                // Albums with parents will be re-mapped after all albums are created
                _ = try? self.database.run(self.albumsTable.insert(
                    self.albumId <- newID,
                    self.albumName <- (try? foreignAlbum.get(albumName)) ?? "",
                    self.albumCoverPhoto <- (try? foreignAlbum.get(albumCoverPhoto)),
                    self.albumParentId <- oldParentID == nil ? targetAlbumID : nil,
                    self.albumDateCreated <- (try? foreignAlbum.get(albumDateCreated)) ?? Date.now.timeIntervalSince1970
                ))
            }

            // Fix parent references for nested albums
            let foreignAlbumsForParents = try foreignDB.prepare(albumsTable)
            for foreignAlbum in foreignAlbumsForParents {
                let oldID = (try? foreignAlbum.get(albumId)) ?? ""
                guard let oldParentID = try? foreignAlbum.get(albumParentId),
                      let newID = albumIDMap[oldID],
                      let newParentID = albumIDMap[oldParentID] else { continue }
                let query = self.albumsTable.filter(self.albumId == newID)
                _ = try? self.database.run(query.update(self.albumParentId <- newParentID))
            }

            // Import pics, mapping their album IDs
            let foreignPics = try foreignDB.prepare(picsTable)
            for foreignPic in foreignPics {
                let pData = try? foreignPic.get(picData)
                let foreignMediaType = (try? foreignPic.get(picMediaType)) ?? 0
                let foreignFilePath = try? foreignPic.get(picFilePath)
                // Skip videos (can't import video files from DB-only backup)
                if foreignMediaType == MediaType.video.rawValue && foreignFilePath != nil {
                    continue
                }
                guard pData != nil || foreignMediaType == MediaType.pic.rawValue else { continue }
                let id = UUID().uuidString
                // Map the pic's album to the new album ID, or target album if it had no album
                let oldAlbumID = try? foreignPic.get(picAlbumId)
                let newAlbumID: String
                if let oldAlbumID, let mapped = albumIDMap[oldAlbumID] {
                    newAlbumID = mapped
                } else {
                    newAlbumID = targetAlbumID
                }
                _ = try? self.database.run(self.picsTable.insert(
                    self.picId <- id,
                    self.picName <- (try? foreignPic.get(picName)) ?? Pic.newFilename(),
                    self.picAlbumId <- newAlbumID,
                    self.picDateAdded <- (try? foreignPic.get(picDateAdded)) ?? Date.now.timeIntervalSince1970,
                    self.picData <- pData,
                    self.picThumbnailData <- (try? foreignPic.get(picThumbnailData)),
                    self.picMediaType <- foreignMediaType,
                    self.picDuration <- (try? foreignPic.get(picDuration)),
                    self.picFilePath <- foreignFilePath
                ))
            }
        } else {
            // Merge
            try self.database.execute("ATTACH DATABASE '\(url.path)' AS backup;")
            try self.database.execute("INSERT OR IGNORE INTO main.albums SELECT * FROM backup.albums;")
            try self.database.execute("INSERT OR IGNORE INTO main.pics SELECT * FROM backup.pics;")
            try self.database.execute("DETACH DATABASE backup;")
        }
    }
}
