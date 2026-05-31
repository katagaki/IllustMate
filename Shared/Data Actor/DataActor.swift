import Foundation
@preconcurrency import SQLite
import SwiftUI

actor DataActor {

    nonisolated(unsafe) private static var _shared = DataActor(collectionID: PicLibrary.defaultID)
    static var shared: DataActor { _shared }

    /// Cache of actors for non-active libraries, so routing sync changes doesn't
    /// open a fresh SQLite connection per record. Guarded by `instancesLock`.
    nonisolated(unsafe) private static var instances: [String: DataActor] = [:]
    private static let instancesLock = NSLock()

    static func switchLibrary(to collectionID: String) {
        instancesLock.lock()
        instances[collectionID] = nil
        instancesLock.unlock()
        _shared = DataActor(collectionID: collectionID)
    }

    /// Returns the shared actor if it serves `collectionID`, else a cached
    /// dedicated actor for that library (used to route incoming sync changes).
    /// Caching keeps a single connection per library — applying or building
    /// thousands of records for a non-active library would otherwise open a new
    /// connection (and re-run schema setup) on every call.
    static func instance(for collectionID: String) -> DataActor {
        if _shared.collectionID == collectionID { return _shared }
        instancesLock.lock()
        defer { instancesLock.unlock() }
        if let existing = instances[collectionID] { return existing }
        let actor = DataActor(collectionID: collectionID)
        instances[collectionID] = actor
        return actor
    }

    nonisolated let collectionID: String
    let database: Connection
    let databaseURL: URL

    let albumsTable = Table("albums")
    let picsTable = Table("pics")
    let preferencesTable = Table("album_preferences")

    let albumId = Expression<String>("id")
    let albumName = Expression<String>("name")
    let albumCoverPhoto = Expression<Data?>("cover_photo")
    let albumParentId = Expression<String?>("parent_album_id")
    let albumDateCreated = Expression<Double>("date_created")

    let picId = Expression<String>("id")
    let picName = Expression<String>("name")
    let picAlbumId = Expression<String?>("containing_album_id")
    let picDateAdded = Expression<Double>("date_added")
    let picData = Expression<Data?>("data")
    let picThumbnailData = Expression<Data?>("thumbnail_data")
    let picMediaType = Expression<Int>("media_type")
    let picDuration = Expression<Double?>("duration")
    let picFilePath = Expression<String?>("file_path")

    let prefAlbumId = Expression<String>("album_id")
    let prefAlbumSort = Expression<String>("album_sort")
    let prefAlbumViewStyle = Expression<String>("album_view_style")
    let prefAlbumColumnCount = Expression<Int>("album_column_count")
    let prefPicSort = Expression<String>("pic_sort")
    let prefPicColumnCount = Expression<Int>("pic_column_count")
    let prefHideSectionHeaders = Expression<Bool>("hide_section_headers")

    // Sync bookkeeping columns (shared by albums + pics)
    let syncDirty = Expression<Bool>("dirty")
    let syncLastModified = Expression<Double>("last_modified")
    let syncCKSystemFields = Expression<Data?>("ck_system_fields")
    // Whether a pic's full-resolution original has been mirrored to iCloud Drive.
    let syncOriginalSynced = Expression<Bool>("original_synced")

    // Tombstones (deleted records, so deletions propagate during sync)
    let tombstonesTable = Table("tombstones")
    let tombstoneId = Expression<String>("id")
    let tombstoneRecordType = Expression<String>("record_type")
    let tombstoneDeletedAt = Expression<Double>("deleted_at")

    // Per-library migration bookkeeping (e.g. the "LibraryV2" image-blob migration).
    let migrationsTable = Table("migrations")
    let migrationName = Expression<String>("migration_name")
    let migrationAppVersion = Expression<String>("app_version")
    let migrationCompleted = Expression<Bool>("completed")

    // swiftlint:disable:next function_body_length
    init(collectionID: String) {
        self.collectionID = collectionID
        let databaseFileName = "Collection.db"
        let fileManager = FileManager.default

        if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.IllustMate"
        ) {
            if collectionID == PicLibrary.defaultID {
                self.databaseURL = appGroupURL.appendingPathComponent(databaseFileName)
            } else {
                let folderURL = appGroupURL.appendingPathComponent(collectionID)
                try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
                self.databaseURL = folderURL.appendingPathComponent(databaseFileName)
            }
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
        // Enable incremental vacuum so space freed by the image-blob migration
        // can be reclaimed in batches. Takes effect on new databases here, and
        // on existing ones after the migration's final VACUUM.
        _ = try? database.execute("PRAGMA auto_vacuum = INCREMENTAL;")
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
                table.column(picMediaType, defaultValue: 0)
                table.column(picDuration)
                table.column(picFilePath)
            })
            if DatabaseMigrator.migrationNeeded() {
                DatabaseMigrator.migrateCollectionDatabase(database,
                    albumsTable: albumsTable, picsTable: picsTable,
                    preferencesTable: preferencesTable)
            }

            try database.run(preferencesTable.create(ifNotExists: true) { table in
                table.column(prefAlbumId, primaryKey: true)
                table.column(prefAlbumSort, defaultValue: "nameAscending")
                table.column(prefAlbumViewStyle, defaultValue: "grid")
                table.column(prefAlbumColumnCount, defaultValue: 4)
                table.column(prefPicSort, defaultValue: "dateAddedDescending")
                table.column(prefPicColumnCount, defaultValue: 4)
                table.column(prefHideSectionHeaders, defaultValue: false)
            })

            for table in [albumsTable, picsTable] {
                _ = try? database.run(table.addColumn(syncDirty, defaultValue: true))
                _ = try? database.run(table.addColumn(syncLastModified, defaultValue: 0))
                _ = try? database.run(table.addColumn(syncCKSystemFields))
            }
            _ = try? database.run(picsTable.addColumn(syncOriginalSynced, defaultValue: false))
            try database.run(tombstonesTable.create(ifNotExists: true) { table in
                table.column(tombstoneId, primaryKey: true)
                table.column(tombstoneRecordType)
                table.column(tombstoneDeletedAt, defaultValue: 0)
            })

            try database.run(migrationsTable.create(ifNotExists: true) { table in
                table.column(migrationName, primaryKey: true)
                table.column(migrationAppVersion, defaultValue: "")
                table.column(migrationCompleted, defaultValue: false)
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

    func albumCoverData(forAlbumWithID albumID: String) -> Data? {
        let query = albumsTable.filter(albumId == albumID).select(albumCoverPhoto)
        guard let row = try? database.pluck(query) else { return nil }
        return try? row.get(albumCoverPhoto)
    }

    func batchAlbumCoverData(forAlbumIDs albumIDs: [String]) -> [String: Data] {
        guard !albumIDs.isEmpty else { return [:] }
        var result: [String: Data] = [:]
        for albumID in albumIDs {
            let query = albumsTable.filter(albumId == albumID).select(albumId, albumCoverPhoto)
            if let row = try? database.pluck(query),
               let data = try? row.get(albumCoverPhoto) {
                result[albumID] = data
            }
        }
        return result
    }

    func picFrom(row: Row) -> Pic {
        let id = (try? row.get(picId)) ?? ""
        let name = (try? row.get(picName)) ?? ""
        let albumId = try? row.get(picAlbumId)
        let dateAdded = Date(timeIntervalSince1970: (try? row.get(picDateAdded)) ?? 0)
        let thumbData = try? row.get(picThumbnailData)
        let mediaTypeRaw = (try? row.get(picMediaType)) ?? 0
        let duration = try? row.get(picDuration)
        let filePath = try? row.get(picFilePath)
        let pic = Pic(id: id, name: name,
                       containingAlbumID: albumId ?? nil,
                       dateAdded: dateAdded,
                       mediaType: MediaType(rawValue: mediaTypeRaw) ?? .pic,
                       duration: duration,
                       filePath: filePath)
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
                    picDateAdded, picThumbnailData,
                    picMediaType, picDuration, picFilePath)
        return (try? database.prepare(query).map { picFrom(row: $0) }) ?? []
    }
}
