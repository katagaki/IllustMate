//
//  LibrariesActor.swift
//  PicMate
//
//  Created by Claude on 2026/03/17.
//

import Foundation
@preconcurrency import SQLite

actor LibrariesActor {

    static let shared = LibrariesActor()

    let database: Connection

    // Table
    let librariesTable = Table("collections")

    // Columns
    let libraryId = Expression<String>("id")
    let libraryName = Expression<String>("name")

    // Sync bookkeeping
    let libraryDirty = Expression<Bool>("dirty")
    let libraryLastModified = Expression<Double>("last_modified")
    let libraryCKSystemFields = Expression<Data?>("ck_system_fields")
    let tombstonesTable = Table("library_tombstones")
    let tombstoneId = Expression<String>("id")
    let tombstoneDeletedAt = Expression<Double>("deleted_at")

    init() {
        let databaseFileName = "Libraries.db"
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
            fatalError("Could not open SQLite libraries database: \(error)")
        }
        self.database = database
        do {
            try database.run(librariesTable.create(ifNotExists: true) { table in
                table.column(libraryId, primaryKey: true)
                table.column(libraryName)
            })
            if DatabaseMigrator.migrationNeeded() {
                DatabaseMigrator.migrateLibrariesDatabase(database, librariesTable: librariesTable)
            }
            // Ensure default library exists
            let defaultExists = try database.scalar(
                librariesTable.filter(libraryId == PicLibrary.defaultID).count
            ) > 0
            if !defaultExists {
                _ = try database.run(librariesTable.insert(
                    libraryId <- PicLibrary.defaultID,
                    libraryName <- ""
                ))
            }
            // Sync bookkeeping (idempotent on existing DBs)
            _ = try? database.run(librariesTable.addColumn(libraryDirty, defaultValue: true))
            _ = try? database.run(librariesTable.addColumn(libraryLastModified, defaultValue: 0))
            _ = try? database.run(librariesTable.addColumn(libraryCKSystemFields))
            try database.run(tombstonesTable.create(ifNotExists: true) { table in
                table.column(tombstoneId, primaryKey: true)
                table.column(tombstoneDeletedAt, defaultValue: 0)
            })
        } catch {
            debugPrint("Libraries database setup error: \(error)")
        }
    }

    // MARK: - Read

    func allLibraries() -> [PicLibrary] {
        let query = librariesTable.order(libraryId.desc)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { row in
            guard let id = try? row.get(libraryId),
                  let name = try? row.get(libraryName) else { return nil }
            return PicLibrary(id: id, name: name)
        }
    }

    func library(for id: String) -> PicLibrary? {
        let query = librariesTable.filter(libraryId == id)
        guard let row = try? database.pluck(query),
              let id = try? row.get(libraryId),
              let name = try? row.get(libraryName) else { return nil }
        return PicLibrary(id: id, name: name)
    }

    // MARK: - Write

    func createLibrary(name: String) -> PicLibrary {
        let id = PicLibrary.newID()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // Create the library's folder
        let fileManager = FileManager.default
        if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.IllustMate"
        ) {
            let folderURL = appGroupURL.appendingPathComponent(id)
            try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        _ = try? database.run(librariesTable.insert(
            libraryId <- id,
            libraryName <- trimmedName,
            libraryDirty <- true,
            libraryLastModified <- Date.now.timeIntervalSince1970
        ))
        return PicLibrary(id: id, name: trimmedName)
    }

    func renameLibrary(withID id: String, to newName: String) {
        let query = librariesTable.filter(libraryId == id)
        _ = try? database.run(query.update(
            libraryName <- newName.trimmingCharacters(in: .whitespaces),
            libraryDirty <- true,
            libraryLastModified <- Date.now.timeIntervalSince1970
        ))
    }

    // MARK: - Delete

    func deleteLibrary(withID id: String) {
        guard id != PicLibrary.defaultID else { return }

        // Record a tombstone so the deletion propagates, then delete the row
        _ = try? database.run(tombstonesTable.insert(or: .replace,
            tombstoneId <- id,
            tombstoneDeletedAt <- Date.now.timeIntervalSince1970
        ))
        let query = librariesTable.filter(libraryId == id)
        _ = try? database.run(query.delete())

        // Delete the folder and all its contents
        let fileManager = FileManager.default
        if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.IllustMate"
        ) {
            let folderURL = appGroupURL.appendingPathComponent(id)
            try? fileManager.removeItem(at: folderURL)
        }
    }
}

extension LibrariesActor {

    // MARK: - Sync bookkeeping (registry, excludes the default library)

    func dirtyLibraryIDs() -> [String] {
        let query = librariesTable
            .filter(libraryDirty == true && libraryId != PicLibrary.defaultID)
            .select(libraryId)
        return (try? database.prepare(query).map { $0[libraryId] }) ?? []
    }

    func pendingLibraryTombstones() -> [String] {
        (try? database.prepare(tombstonesTable).map { $0[tombstoneId] }) ?? []
    }

    func removeLibraryTombstone(id: String) {
        _ = try? database.run(tombstonesTable.filter(tombstoneId == id).delete())
    }

    func librarySyncSnapshot(forID id: String) -> LibrarySyncSnapshot? {
        guard let row = try? database.pluck(librariesTable.filter(libraryId == id)) else { return nil }
        return LibrarySyncSnapshot(
            id: id,
            name: (try? row.get(libraryName)) ?? "",
            systemFields: try? row.get(libraryCKSystemFields),
            lastModified: (try? row.get(libraryLastModified)) ?? 0
        )
    }

    func markLibrarySynced(id: String, systemFields: Data?) {
        _ = try? database.run(librariesTable.filter(libraryId == id)
            .update(libraryDirty <- false, libraryCKSystemFields <- systemFields))
    }

    /// True if the library has been synced to iCloud (has stored system fields).
    func isLibrarySynced(id: String) -> Bool {
        guard let row = try? database.pluck(librariesTable.filter(libraryId == id)) else { return false }
        return (try? row.get(libraryCKSystemFields)) != nil
    }

    func applyRemoteLibrary(_ snapshot: LibrarySyncSnapshot) {
        guard snapshot.id != PicLibrary.defaultID else { return }
        ensureFolder(for: snapshot.id)
        let exists = ((try? database.scalar(librariesTable.filter(libraryId == snapshot.id).count)) ?? 0) > 0
        if exists {
            _ = try? database.run(librariesTable.filter(libraryId == snapshot.id).update(
                libraryName <- snapshot.name,
                libraryDirty <- false,
                libraryCKSystemFields <- snapshot.systemFields,
                libraryLastModified <- snapshot.lastModified
            ))
        } else {
            _ = try? database.run(librariesTable.insert(or: .replace,
                libraryId <- snapshot.id,
                libraryName <- snapshot.name,
                libraryDirty <- false,
                libraryCKSystemFields <- snapshot.systemFields,
                libraryLastModified <- snapshot.lastModified
            ))
        }
    }

    func removeLibraryForRemoteDelete(id: String) {
        guard id != PicLibrary.defaultID else { return }
        _ = try? database.run(librariesTable.filter(libraryId == id).delete())
        let fileManager = FileManager.default
        if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.IllustMate"
        ) {
            try? fileManager.removeItem(at: appGroupURL.appendingPathComponent(id))
        }
    }

    private func ensureFolder(for id: String) {
        let fileManager = FileManager.default
        if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.IllustMate"
        ) {
            let folderURL = appGroupURL.appendingPathComponent(id)
            if !fileManager.fileExists(atPath: folderURL.path) {
                try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }
        }
    }
}
