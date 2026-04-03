//
//  DatabaseMigrator.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/04/02.
//

import Foundation
@preconcurrency import SQLite

struct DatabaseMigrator {

    private static let appGroupID = "group.com.tsubuzaki.IllustMate"
    private static let migratedVersionKey = "DatabaseMigratedVersion"

    /// Returns true if a migration is needed (app version changed or first launch).
    static func migrationNeeded() -> Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let defaults = UserDefaults(suiteName: appGroupID)
        let migratedVersion = defaults?.string(forKey: migratedVersionKey)
        return migratedVersion != currentVersion
    }

    /// Records the current app version as migrated.
    static func markMigrationComplete() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(currentVersion, forKey: migratedVersionKey)
    }

    // MARK: - Collection DB (albums + pics + preferences)

    static func migrateCollectionDatabase(_ database: Connection,
                                          albumsTable: Table,
                                          picsTable: Table,
                                          preferencesTable: Table) {
        // Albums columns
        let albumCoverPhoto = Expression<Data?>("cover_photo")
        let albumParentId = Expression<String?>("parent_album_id")
        let albumDateCreated = Expression<Double>("date_created")
        _ = try? database.run(albumsTable.addColumn(albumCoverPhoto))
        _ = try? database.run(albumsTable.addColumn(albumParentId))
        _ = try? database.run(albumsTable.addColumn(albumDateCreated, defaultValue: 0))

        // Pics columns
        let picName = Expression<String>("name")
        let picAlbumId = Expression<String?>("containing_album_id")
        let picDateAdded = Expression<Double>("date_added")
        let picData = Expression<Data?>("data")
        let picThumbnailData = Expression<Data?>("thumbnail_data")
        let picMediaType = Expression<Int>("media_type")
        let picDuration = Expression<Double?>("duration")
        let picFilePath = Expression<String?>("file_path")
        _ = try? database.run(picsTable.addColumn(picName, defaultValue: ""))
        _ = try? database.run(picsTable.addColumn(picAlbumId))
        _ = try? database.run(picsTable.addColumn(picDateAdded, defaultValue: 0))
        _ = try? database.run(picsTable.addColumn(picData))
        _ = try? database.run(picsTable.addColumn(picThumbnailData))
        _ = try? database.run(picsTable.addColumn(picMediaType, defaultValue: 0))
        _ = try? database.run(picsTable.addColumn(picDuration))
        _ = try? database.run(picsTable.addColumn(picFilePath))

        // Preferences columns
        let prefAlbumSort = Expression<String>("album_sort")
        let prefAlbumViewStyle = Expression<String>("album_view_style")
        let prefAlbumColumnCount = Expression<Int>("album_column_count")
        let prefPicSort = Expression<String>("pic_sort")
        let prefPicColumnCount = Expression<Int>("pic_column_count")
        let prefHideSectionHeaders = Expression<Bool>("hide_section_headers")
        _ = try? database.run(preferencesTable.addColumn(prefAlbumSort, defaultValue: "nameAscending"))
        _ = try? database.run(preferencesTable.addColumn(prefAlbumViewStyle, defaultValue: "grid"))
        _ = try? database.run(preferencesTable.addColumn(prefAlbumColumnCount, defaultValue: 4))
        _ = try? database.run(preferencesTable.addColumn(prefPicSort, defaultValue: "dateAddedDescending"))
        _ = try? database.run(preferencesTable.addColumn(prefPicColumnCount, defaultValue: 4))
        _ = try? database.run(preferencesTable.addColumn(prefHideSectionHeaders, defaultValue: false))
    }

    // MARK: - Hashes DB

    static func migrateHashDatabase(_ database: Connection, picHashesTable: Table) {
        let hashValue = Expression<Int64>("dhash")
        let hashVersion = Expression<Int>("hash_version")
        _ = try? database.run(picHashesTable.addColumn(hashValue, defaultValue: 0))
        _ = try? database.run(picHashesTable.addColumn(hashVersion, defaultValue: 1))
    }

    // MARK: - PColors DB

    static func migrateColorDatabase(_ database: Connection, picColorsTable: Table) {
        let colorRed = Expression<Int>("red")
        let colorGreen = Expression<Int>("green")
        let colorBlue = Expression<Int>("blue")
        _ = try? database.run(picColorsTable.addColumn(colorRed, defaultValue: 0))
        _ = try? database.run(picColorsTable.addColumn(colorGreen, defaultValue: 0))
        _ = try? database.run(picColorsTable.addColumn(colorBlue, defaultValue: 0))
    }

    // MARK: - Cover Cache DB

    static func migrateCoverCacheDatabase(_ database: Connection, coverCacheTable: Table) {
        let cacheVersionKey = Expression<String>("version_key")
        let cachePrimary = Expression<Data?>("primary_data")
        let cacheSecondary = Expression<Data?>("secondary_data")
        let cacheTertiary = Expression<Data?>("tertiary_data")
        _ = try? database.run(coverCacheTable.addColumn(cacheVersionKey, defaultValue: ""))
        _ = try? database.run(coverCacheTable.addColumn(cachePrimary))
        _ = try? database.run(coverCacheTable.addColumn(cacheSecondary))
        _ = try? database.run(coverCacheTable.addColumn(cacheTertiary))
    }

    // MARK: - Libraries DB

    static func migrateLibrariesDatabase(_ database: Connection, librariesTable: Table) {
        let libraryName = Expression<String>("name")
        _ = try? database.run(librariesTable.addColumn(libraryName, defaultValue: ""))
    }
}
