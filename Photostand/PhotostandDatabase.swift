//
//  PhotostandDatabase.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import Foundation
@preconcurrency import SQLite
import UIKit

struct PhotostandDatabase {
    static let appGroupID = "group.com.tsubuzaki.IllustMate"

    // Tables
    static let albumsTable = Table("albums")
    static let picsTable = Table("pics")

    // Album columns
    static let albumId = Expression<String>("id")
    static let albumName = Expression<String>("name")

    // Pic columns
    static let picId = Expression<String>("id")
    static let picAlbumId = Expression<String?>("containing_album_id")
    static let picData = Expression<Data?>("data")
    static let picMediaType = Expression<Int>("media_type")
    static let picFilePath = Expression<String?>("file_path")

    /// Maximum blob size (in bytes) the widget will attempt to load.
    static let maxBlobSize = 25 * 1024 * 1024 // 25 MB

    /// iCloud Drive container where synced libraries keep their originals.
    static let ubiquityContainerID = "iCloud.com.tsubuzaki.IllustMate"
    /// The widget only reads the default library (Collection.db at the app-group root).
    static let defaultLibraryID = "__default__"

    struct AlbumRecord {
        let id: String
        let name: String
    }

    static func openDatabase() -> Connection? {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("Collection.db") else { return nil }
        return try? Connection(url.path, readonly: true)
    }

    static func fetchAllAlbums() -> [AlbumRecord] {
        guard let database = openDatabase() else { return [] }
        let query = albumsTable.select(albumId, albumName).order(albumName.asc)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { row in
            guard let id = try? row.get(albumId),
                  let name = try? row.get(albumName) else { return nil }
            return AlbumRecord(id: id, name: name)
        }
    }

    static func fetchAlbum(withID id: String) -> AlbumRecord? {
        guard let database = openDatabase() else { return nil }
        let query = albumsTable.filter(albumId == id).select(albumId, albumName)
        guard let row = try? database.pluck(query),
              let rowId = try? row.get(albumId),
              let name = try? row.get(albumName) else { return nil }
        return AlbumRecord(id: rowId, name: name)
    }

    static func fetchRandomPicData(
        inAlbumWithID albumID: String,
        maxDimension: CGFloat = 800
    ) -> Data? {
        guard let database = openDatabase() else { return nil }
        return fetchRandomPicData(using: database, albumID: albumID, maxDimension: maxDimension)
    }

    /// Fetches a single random image using a provided database connection.
    /// Skips photos whose blob exceeds `maxBlobSize` to stay within the widget memory limit.
    static func fetchRandomPicData(
        using database: Connection,
        albumID: String,
        maxDimension: CGFloat = 800
    ) -> Data? {
        // Step 1: Pick a random image pic ID.
        let idQuery = picsTable
            .filter(picAlbumId == albumID)
            .filter(picMediaType == 0)
            .select(picId)
            .order(Expression<Int>.random())
            .limit(1)
        guard let idRow = try? database.pluck(idQuery),
              let randomId = try? idRow.get(picId),
              let data = rawPicData(forID: randomId, using: database) else { return nil }
        // Step 2: Downsample directly at target size.
        return UIImage.downsampledForWidget(data: data, maxDimension: maxDimension)
    }

    /// Fetches multiple random images, reusing a single database connection.
    /// Skips photos whose blob exceeds `maxBlobSize` to stay within the widget memory limit.
    static func fetchRandomPicDataMultiple(
        inAlbumWithID albumID: String,
        count: Int,
        maxDimension: CGFloat = 800
    ) -> [Data] {
        guard let database = openDatabase() else { return [] }
        let idQuery = picsTable
            .filter(picAlbumId == albumID)
            .filter(picMediaType == 0)
            .select(picId)
            .order(Expression<Int>.random())
            .limit(count)
        guard let rows = try? database.prepare(idQuery) else { return [] }
        let ids = rows.compactMap { try? $0.get(picId) }
        return ids.compactMap { id in
            autoreleasepool {
                guard let data = rawPicData(forID: id, using: database) else { return nil }
                return UIImage.downsampledForWidget(data: data, maxDimension: maxDimension)
            }
        }
    }

    /// Resolves a pic's raw bytes, preferring the externalized image file and
    /// falling back to the legacy blob. Skips items larger than `maxBlobSize`
    /// to stay within the widget's memory limit.
    private static func rawPicData(forID id: String, using database: Connection) -> Data? {
        let query = picsTable.filter(picId == id).select(picData, picFilePath, picMediaType)
        guard let row = try? database.pluck(query) else { return nil }
        // 1. Local externalized file (non-synced libraries).
        if let path = try? row.get(picFilePath),
           let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
           let data = cappedData(at: containerURL.appendingPathComponent(path)) {
            return data
        }
        // 2. iCloud Drive container (synced libraries keep originals here).
        if (try? row.get(picMediaType)) == 0, let data = ubiquityImageData(forID: id) {
            return data
        }
        // 3. Legacy blob.
        guard let blob = try? row.get(picData), blob.count <= maxBlobSize else { return nil }
        return blob
    }

    /// Reads a file capped at `maxBlobSize`, or nil if it's missing or too large.
    private static func cappedData(at fileURL: URL) -> Data? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let size = (attributes?[.size] as? NSNumber)?.int64Value,
              size <= Int64(maxBlobSize) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    /// Reads a synced original from the iCloud Drive container if it's already
    /// materialized; otherwise requests a download for a future widget refresh.
    private static func ubiquityImageData(forID id: String) -> Data? {
        guard let container = FileManager.default
            .url(forUbiquityContainerIdentifier: ubiquityContainerID) else { return nil }
        let fileURL = container.appendingPathComponent("Originals", isDirectory: true)
            .appendingPathComponent(defaultLibraryID, isDirectory: true)
            .appendingPathComponent(id)
        let status = try? fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            .ubiquitousItemDownloadingStatus
        if status == .current {
            return cappedData(at: fileURL)
        }
        try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
        return nil
    }

    static func fetchPicCount(inAlbumWithID albumID: String) -> Int {
        guard let database = openDatabase() else { return 0 }
        let query = picsTable.filter(picAlbumId == albumID).filter(picMediaType == 0)
        return (try? database.scalar(query.count)) ?? 0
    }
}
