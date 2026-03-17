//
//  CollectionsActor.swift
//  PicMate
//
//  Created by Claude on 2026/03/17.
//

import Foundation
@preconcurrency import SQLite

actor CollectionsActor {

    static let shared = CollectionsActor()

    let database: Connection

    // Table
    let collectionsTable = Table("collections")

    // Columns
    let collectionId = Expression<String>("id")
    let collectionName = Expression<String>("name")

    init() {
        let databaseFileName = "Collections.db"
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
            fatalError("Could not open SQLite collections database: \(error)")
        }
        self.database = database
        do {
            try database.run(collectionsTable.create(ifNotExists: true) { table in
                table.column(collectionId, primaryKey: true)
                table.column(collectionName)
            })
            // Ensure default collection exists
            let defaultExists = try database.scalar(
                collectionsTable.filter(collectionId == Collection.defaultID).count
            ) > 0
            if !defaultExists {
                _ = try database.run(collectionsTable.insert(
                    collectionId <- Collection.defaultID,
                    collectionName <- ""
                ))
            }
        } catch {
            debugPrint("Collections database setup error: \(error)")
        }
    }

    // MARK: - Read

    func allCollections() -> [Collection] {
        let query = collectionsTable.order(collectionId.asc)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { row in
            guard let id = try? row.get(collectionId),
                  let name = try? row.get(collectionName) else { return nil }
            return Collection(id: id, name: name)
        }
    }

    func collection(for id: String) -> Collection? {
        let query = collectionsTable.filter(collectionId == id)
        guard let row = try? database.pluck(query),
              let id = try? row.get(collectionId),
              let name = try? row.get(collectionName) else { return nil }
        return Collection(id: id, name: name)
    }

    // MARK: - Write

    func createCollection(name: String) -> Collection {
        let id = Collection.newID()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // Create the collection's folder
        let fileManager = FileManager.default
        if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.IllustMate"
        ) {
            let folderURL = appGroupURL.appendingPathComponent(id)
            try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        _ = try? database.run(collectionsTable.insert(
            collectionId <- id,
            collectionName <- trimmedName
        ))
        return Collection(id: id, name: trimmedName)
    }

    func renameCollection(withID id: String, to newName: String) {
        let query = collectionsTable.filter(collectionId == id)
        _ = try? database.run(query.update(collectionName <- newName.trimmingCharacters(in: .whitespaces)))
    }

    // MARK: - Delete

    func deleteCollection(withID id: String) {
        guard id != Collection.defaultID else { return }

        // Delete the row
        let query = collectionsTable.filter(collectionId == id)
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
