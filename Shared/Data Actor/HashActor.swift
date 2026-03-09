//
//  HashActor.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/09.
//

import Foundation
@preconcurrency import SQLite

actor HashActor {

    static let shared = HashActor()

    let database: Connection

    // Table
    let picHashesTable = Table("pic_hashes")

    // Columns
    let hashPicId = Expression<String>("pic_id")
    let hashValue = Expression<Int64>("dhash")
    let hashVersion = Expression<Int>("hash_version")

    init() {
        let databaseFileName = "Hashes.db"
        let fileManager = FileManager.default

        let databaseURL: URL
        if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.IllustMate"
        ) {
            databaseURL = appGroupURL.appendingPathComponent(databaseFileName)
        } else {
            fatalError()
        }

        let database: Connection
        do {
            database = try Connection(databaseURL.path)
        } catch {
            fatalError("Could not open SQLite hash database: \(error)")
        }
        self.database = database
        do {
            try database.run(picHashesTable.create(ifNotExists: true) { table in
                table.column(hashPicId, primaryKey: true)
                table.column(hashValue)
                table.column(hashVersion, defaultValue: 1)
            })
        } catch {
            debugPrint("Hash database setup error: \(error)")
        }
    }

    // MARK: - Read

    func cachedHash(forPicWithID picID: String) -> UInt64? {
        let query = picHashesTable.filter(hashPicId == picID).select(hashValue)
        guard let row = try? database.pluck(query),
              let value = try? row.get(hashValue) else { return nil }
        return UInt64(bitPattern: value)
    }

    func allCachedHashes() -> [(String, UInt64)] {
        let query = picHashesTable.select(hashPicId, hashValue)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { row in
            guard let picID = try? row.get(hashPicId),
                  let value = try? row.get(hashValue) else { return nil }
            return (picID, UInt64(bitPattern: value))
        }
    }

    func picIDsWithCachedHash() -> Set<String> {
        let query = picHashesTable.select(hashPicId)
        guard let rows = try? database.prepare(query) else { return [] }
        var ids = Set<String>()
        for row in rows {
            if let picID = try? row.get(hashPicId) {
                ids.insert(picID)
            }
        }
        return ids
    }

    // MARK: - Write

    func storeHash(_ hash: UInt64, forPicWithID picID: String) {
        let signedHash = Int64(bitPattern: hash)
        _ = try? database.run(picHashesTable.insert(or: .replace,
            hashPicId <- picID,
            hashValue <- signedHash,
            hashVersion <- 1
        ))
    }

    // MARK: - Delete

    func deleteHash(forPicWithID picID: String) {
        let query = picHashesTable.filter(hashPicId == picID)
        _ = try? database.run(query.delete())
    }

    func deleteAllHashes() {
        _ = try? database.run(picHashesTable.delete())
    }
}
