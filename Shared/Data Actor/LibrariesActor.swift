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
            libraryName <- trimmedName
        ))
        return PicLibrary(id: id, name: trimmedName)
    }

    func renameLibrary(withID id: String, to newName: String) {
        let query = librariesTable.filter(libraryId == id)
        _ = try? database.run(query.update(libraryName <- newName.trimmingCharacters(in: .whitespaces)))
    }

    // MARK: - Delete

    func deleteLibrary(withID id: String) {
        guard id != PicLibrary.defaultID else { return }

        // Delete the row
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
