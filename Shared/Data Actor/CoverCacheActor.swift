import Foundation
@preconcurrency import SQLite

actor CoverCacheActor {

    nonisolated(unsafe) private static var _shared = CoverCacheActor(collectionID: PicLibrary.defaultID)
    static var shared: CoverCacheActor { _shared }

    static func switchLibrary(to collectionID: String) {
        _shared = CoverCacheActor(collectionID: collectionID)
    }

    let database: Connection

    let coverCacheTable = Table("cover_cache")

    let cacheAlbumId = Expression<String>("album_id")
    let cacheVersionKey = Expression<String>("version_key")
    let cachePrimary = Expression<Data?>("primary_data")
    let cacheSecondary = Expression<Data?>("secondary_data")
    let cacheTertiary = Expression<Data?>("tertiary_data")

    init(collectionID: String) {
        let databaseFileName = "CoverCache.db"
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
            fatalError("Could not open SQLite cover cache database: \(error)")
        }
        self.database = database
        do {
            try database.run(coverCacheTable.create(ifNotExists: true) { table in
                table.column(cacheAlbumId, primaryKey: true)
                table.column(cacheVersionKey)
                table.column(cachePrimary)
                table.column(cacheSecondary)
                table.column(cacheTertiary)
            })
            if DatabaseMigrator.migrationNeeded() {
                DatabaseMigrator.migrateCoverCacheDatabase(database, coverCacheTable: coverCacheTable)
            }
        } catch {
            debugPrint("Cover cache database setup error: \(error)")
        }
    }

    // MARK: - Read

    struct CachedCoverData {
        let primary: Data?
        let secondary: Data?
        let tertiary: Data?
    }

    func cachedCover(forAlbumWithID albumID: String, versionKey: String) -> CachedCoverData? {
        let query = coverCacheTable.filter(cacheAlbumId == albumID)
        guard let row = try? database.pluck(query) else { return nil }

        guard let storedKey = try? row.get(cacheVersionKey),
              storedKey == versionKey else {
            _ = try? database.run(coverCacheTable.filter(cacheAlbumId == albumID).delete())
            return nil
        }

        return CachedCoverData(
            primary: try? row.get(cachePrimary),
            secondary: try? row.get(cacheSecondary),
            tertiary: try? row.get(cacheTertiary)
        )
    }

    // MARK: - Write

    func storeCover(
        primary: Data?, secondary: Data?, tertiary: Data?,
        forAlbumWithID albumID: String, versionKey: String
    ) {
        _ = try? database.run(coverCacheTable.insert(or: .replace,
            cacheAlbumId <- albumID,
            cacheVersionKey <- versionKey,
            cachePrimary <- primary,
            cacheSecondary <- secondary,
            cacheTertiary <- tertiary
        ))
    }

    // MARK: - Delete

    func deleteCover(forAlbumWithID albumID: String) {
        let query = coverCacheTable.filter(cacheAlbumId == albumID)
        _ = try? database.run(query.delete())
    }

    func deleteAllCovers() {
        _ = try? database.run(coverCacheTable.delete())
    }
}
