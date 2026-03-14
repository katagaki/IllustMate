//
//  PColorActor.swift
//  PicMate
//
//  Created by Claude on 2026/03/14.
//

import Foundation
@preconcurrency import SQLite

actor PColorActor {

    static let shared = PColorActor()

    let database: Connection

    // Table
    let picColorsTable = Table("pic_colors")

    // Columns
    let colorPicId = Expression<String>("pic_id")
    let colorRed = Expression<Int>("red")
    let colorGreen = Expression<Int>("green")
    let colorBlue = Expression<Int>("blue")

    init() {
        let databaseFileName = "PColors.db"
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
            fatalError("Could not open SQLite color database: \(error)")
        }
        self.database = database
        do {
            try database.run(picColorsTable.create(ifNotExists: true) { table in
                table.column(colorPicId, primaryKey: true)
                table.column(colorRed)
                table.column(colorGreen)
                table.column(colorBlue)
            })
        } catch {
            debugPrint("Color database setup error: \(error)")
        }
    }

    // MARK: - Read

    func cachedColor(forPicWithID picID: String) -> (r: Int, g: Int, b: Int)? {
        let query = picColorsTable.filter(colorPicId == picID)
            .select(colorRed, colorGreen, colorBlue)
        guard let row = try? database.pluck(query),
              let r = try? row.get(colorRed),
              let g = try? row.get(colorGreen),
              let b = try? row.get(colorBlue) else { return nil }
        return (r, g, b)
    }

    func allCachedColors() -> [String: (r: Int, g: Int, b: Int)] {
        let query = picColorsTable.select(colorPicId, colorRed, colorGreen, colorBlue)
        guard let rows = try? database.prepare(query) else { return [:] }
        var result: [String: (r: Int, g: Int, b: Int)] = [:]
        for row in rows {
            guard let picID = try? row.get(colorPicId),
                  let r = try? row.get(colorRed),
                  let g = try? row.get(colorGreen),
                  let b = try? row.get(colorBlue) else { continue }
            result[picID] = (r, g, b)
        }
        return result
    }

    func picIDsWithCachedColor() -> Set<String> {
        let query = picColorsTable.select(colorPicId)
        guard let rows = try? database.prepare(query) else { return [] }
        var ids = Set<String>()
        for row in rows {
            if let picID = try? row.get(colorPicId) {
                ids.insert(picID)
            }
        }
        return ids
    }

    // MARK: - Write

    func storeColor(red: Int, green: Int, blue: Int, forPicWithID picID: String) {
        _ = try? database.run(picColorsTable.insert(or: .replace,
            colorPicId <- picID,
            colorRed <- red,
            colorGreen <- green,
            colorBlue <- blue
        ))
    }

    func storeColors(_ colors: [(picID: String, r: Int, g: Int, b: Int)]) {
        guard !colors.isEmpty else { return }
        _ = try? database.transaction {
            for color in colors {
                _ = try? database.run(picColorsTable.insert(or: .replace,
                    colorPicId <- color.picID,
                    colorRed <- color.r,
                    colorGreen <- color.g,
                    colorBlue <- color.b
                ))
            }
        }
    }

    // MARK: - Delete

    func deleteColor(forPicWithID picID: String) {
        let query = picColorsTable.filter(colorPicId == picID)
        _ = try? database.run(query.delete())
    }

    func deleteAllColors() {
        _ = try? database.run(picColorsTable.delete())
    }
}
