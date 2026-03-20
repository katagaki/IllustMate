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
    static let picData = Expression<Data>("data")

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

    static func fetchRandomPicData(inAlbumWithID albumID: String) -> Data? {
        guard let database = openDatabase() else { return nil }
        // Step 1: Pick a random pic ID without loading blob data
        let idQuery = picsTable
            .filter(picAlbumId == albumID)
            .select(picId)
            .order(Expression<Int>.random())
            .limit(1)
        guard let idRow = try? database.pluck(idQuery),
              let randomId = try? idRow.get(picId) else { return nil }
        // Step 2: Fetch and resize in autoreleasepool so the full-size UIImage is freed
        return autoreleasepool {
            let dataQuery = picsTable
                .filter(picId == randomId)
                .select(picData)
            guard let row = try? database.pluck(dataQuery),
                  let data = try? row.get(picData),
                  let image = UIImage(data: data) else { return nil }
            return image.resizedForWidget()
        }
    }

    static func fetchRandomPicDataMultiple(
        inAlbumWithID albumID: String,
        count: Int,
        maxDimension: CGFloat = 800
    ) -> [Data] {
        guard let database = openDatabase() else { return [] }
        let idQuery = picsTable
            .filter(picAlbumId == albumID)
            .select(picId)
            .order(Expression<Int>.random())
            .limit(count)
        guard let rows = try? database.prepare(idQuery) else { return [] }
        let ids = rows.compactMap { try? $0.get(picId) }
        return ids.compactMap { id in
            // Autoreleasepool ensures each full-size UIImage is freed before loading the next
            autoreleasepool {
                let dataQuery = picsTable
                    .filter(picId == id)
                    .select(picData)
                guard let row = try? database.pluck(dataQuery),
                      let data = try? row.get(picData),
                      let image = UIImage(data: data) else { return nil }
                return image.resizedForWidget(maxDimension: maxDimension)
            }
        }
    }

    static func fetchPicCount(inAlbumWithID albumID: String) -> Int {
        guard let database = openDatabase() else { return 0 }
        let query = picsTable.filter(picAlbumId == albumID)
        return (try? database.scalar(query.count)) ?? 0
    }
}
