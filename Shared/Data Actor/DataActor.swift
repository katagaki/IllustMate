//
//  DataActor.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/17.
//

import Foundation
@preconcurrency import SQLite
import SwiftUI

actor DataActor {

    static let shared = DataActor()

    let database: Connection
    let databaseURL: URL

    // Tables
    let albumsTable = Table("albums")
    let picsTable = Table("pics")

    // Album columns
    let albumId = Expression<String>("id")
    let albumName = Expression<String>("name")
    let albumCoverPhoto = Expression<Data?>("cover_photo")
    let albumParentId = Expression<String?>("parent_album_id")
    let albumDateCreated = Expression<Double>("date_created")

    // Pic columns
    let picId = Expression<String>("id")
    let picName = Expression<String>("name")
    let picAlbumId = Expression<String?>("containing_album_id")
    let picDateAdded = Expression<Double>("date_added")
    let picData = Expression<Data>("data")
    let picThumbnailData = Expression<Data?>("thumbnail_data")

    init() {
        let databaseFileName = "Collection.db"
        let fileManager = FileManager.default

        if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.IllustMate"
        ) {
            self.databaseURL = appGroupURL.appendingPathComponent(databaseFileName)
        } else {
            fatalError()
        }

        let database: Connection
        do {
            database = try Connection(self.databaseURL.path)
        } catch {
            fatalError("Could not open SQLite database: \(error)")
        }
        self.database = database
        do {
            try database.run(albumsTable.create(ifNotExists: true) { table in
                table.column(albumId, primaryKey: true)
                table.column(albumName)
                table.column(albumCoverPhoto)
                table.column(albumParentId)
                table.column(albumDateCreated)
            })
            try database.run(picsTable.create(ifNotExists: true) { table in
                table.column(picId, primaryKey: true)
                table.column(picName)
                table.column(picAlbumId)
                table.column(picDateAdded)
                table.column(picData)
                table.column(picThumbnailData)
            })
            try database.run(albumsTable.createIndex(albumParentId, ifNotExists: true))
            try database.run(picsTable.createIndex(picAlbumId, ifNotExists: true))
        } catch {
            debugPrint("Database setup error: \(error)")
        }
    }

    func vacuum() {
        _ = try? self.database.vacuum()
    }

    // MARK: - Row to Model Helpers

    func albumFrom(row: Row, loadChildren: Bool = false) -> Album {
        let id = (try? row.get(albumId)) ?? ""
        let name = (try? row.get(albumName)) ?? ""
        let cover = try? row.get(albumCoverPhoto)
        let parentId = try? row.get(albumParentId)
        let dateCreated = Date(timeIntervalSince1970: (try? row.get(albumDateCreated)) ?? 0)
        let album = Album(id: id, name: name, coverPhoto: cover ?? nil,
                          parentAlbumID: parentId ?? nil, dateCreated: dateCreated)
        if loadChildren {
            album.childAlbums = fetchChildAlbums(forAlbumID: id)
            album.childPics = fetchChildPics(forAlbumID: id)
        }
        return album
    }

    func picFrom(row: Row) -> Pic {
        let id = (try? row.get(picId)) ?? ""
        let name = (try? row.get(picName)) ?? ""
        let albumId = try? row.get(picAlbumId)
        let dateAdded = Date(timeIntervalSince1970: (try? row.get(picDateAdded)) ?? 0)
        let thumbData = try? row.get(picThumbnailData)
        let pic = Pic(id: id, name: name,
                                        containingAlbumID: albumId ?? nil,
                                        dateAdded: dateAdded)
        pic.thumbnailData = thumbData ?? nil
        return pic
    }

    func fetchChildAlbums(forAlbumID id: String) -> [Album] {
        let query = albumsTable.filter(albumParentId == id)
        return (try? database.prepare(query).map { albumFrom(row: $0, loadChildren: false) }) ?? []
    }

    func fetchChildPics(forAlbumID id: String) -> [Pic] {
        let query = picsTable
            .filter(picAlbumId == id)
            .select(picId, picName, picAlbumId,
                    picDateAdded, picThumbnailData)
        return (try? database.prepare(query).map { picFrom(row: $0) }) ?? []
    }

    func backupDatabase(to destinationDirectoryURL: URL) throws {
        if destinationDirectoryURL.startAccessingSecurityScopedResource() {
            defer { destinationDirectoryURL.stopAccessingSecurityScopedResource() }
            let fileManager = FileManager.default
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let backupFileName = "Backup-\(timestamp).pics"

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

    func importFromBackup(at url: URL, targetAlbumID: String?) throws {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let foreignDB = try Connection(url.path)

        if let targetAlbumID {
            let foreignPics = try foreignDB.prepare(picsTable)
            for foreignPic in foreignPics {
                if let pData = try? foreignPic.get(picData) {
                    let id = UUID().uuidString
                    _ = try? self.database.run(self.picsTable.insert(
                        self.picId <- id,
                        self.picName <- (try? foreignPic.get(picName)) ?? Pic.newFilename(),
                        self.picAlbumId <- targetAlbumID,
                        self.picDateAdded <- (try? foreignPic.get(picDateAdded)) ?? Date.now.timeIntervalSince1970,
                        self.picData <- pData,
                        self.picThumbnailData <- (try? foreignPic.get(picThumbnailData))
                    ))
                }
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
