import Foundation
@preconcurrency import SQLite

actor HashActor {

    nonisolated(unsafe) private static var _shared = HashActor(collectionID: PicLibrary.defaultID)
    static var shared: HashActor { _shared }

    /// Bumped to 2 when duplicate scanning switched from hashing full-resolution originals to
    /// hashing the (always-present, synced) thumbnail. Hashes stored under an older version are
    /// treated as uncached so they get recomputed from the thumbnail on the next scan.
    static let currentHashVersion = 2

    static func switchLibrary(to collectionID: String) {
        _shared = HashActor(collectionID: collectionID)
    }

    /// Returns the shared instance when it already targets the requested library, otherwise a
    /// transient instance bound to that library's hash database. Mirrors `DataActor.instance(for:)`
    /// so callers (e.g. sync) can address a non-active library's cache without disturbing the
    /// active one's connection.
    static func instance(for collectionID: String) -> HashActor {
        if collectionID == _shared.collectionID {
            return _shared
        }
        return HashActor(collectionID: collectionID)
    }

    nonisolated let collectionID: String

    let database: Connection

    let picHashesTable = Table("pic_hashes")

    let hashPicId = Expression<String>("pic_id")
    let hashValue = Expression<Int64>("dhash")
    let hashVersion = Expression<Int>("hash_version")

    init(collectionID: String) {
        self.collectionID = collectionID
        let databaseFileName = "Hashes.db"
        let fileManager = FileManager.default

        let databaseURL: URL
        if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.IllustMate"
        ) {
            if collectionID == PicLibrary.defaultID {
                databaseURL = appGroupURL.appendingPathComponent(databaseFileName)
            } else {
                let folderURL = appGroupURL.appendingPathComponent(collectionID)
                try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
                databaseURL = folderURL.appendingPathComponent(databaseFileName)
            }
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
            if DatabaseMigrator.migrationNeeded() {
                DatabaseMigrator.migrateHashDatabase(database, picHashesTable: picHashesTable)
            }
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
        let query = picHashesTable
            .filter(hashVersion == Self.currentHashVersion)
            .select(hashPicId, hashValue)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { row in
            guard let picID = try? row.get(hashPicId),
                  let value = try? row.get(hashValue) else { return nil }
            return (picID, UInt64(bitPattern: value))
        }
    }

    func picIDsWithCachedHash() -> Set<String> {
        let query = picHashesTable
            .filter(hashVersion == Self.currentHashVersion)
            .select(hashPicId)
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
            hashVersion <- Self.currentHashVersion
        ))
    }

    // MARK: - Delete

    func deleteHash(forPicWithID picID: String) {
        let query = picHashesTable.filter(hashPicId == picID)
        _ = try? database.run(query.delete())
    }

    func deleteHashes(forPicIDs picIDs: [String]) {
        guard !picIDs.isEmpty else { return }
        let query = picHashesTable.filter(picIDs.contains(hashPicId))
        _ = try? database.run(query.delete())
    }

    func deleteAllHashes() {
        _ = try? database.run(picHashesTable.delete())
    }
}
