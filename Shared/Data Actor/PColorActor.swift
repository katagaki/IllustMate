//
//  PColorActor.swift
//  PicMate
//
//  Created by Claude on 2026/03/14.
//

import Foundation
@preconcurrency import SQLite

actor PColorActor {

    nonisolated(unsafe) private static var _shared = PColorActor(collectionID: PicLibrary.defaultID)
    static var shared: PColorActor { _shared }

    static func switchLibrary(to collectionID: String) {
        _shared = PColorActor(collectionID: collectionID)
    }

    let database: Connection

    // Table
    let picColorsTable = Table("pic_colors")

    // Columns
    let colorPicId = Expression<String>("pic_id")
    let colorRed = Expression<Int>("red")
    let colorGreen = Expression<Int>("green")
    let colorBlue = Expression<Int>("blue")

    init(collectionID: String) {
        let databaseFileName = "PColors.db"
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

    func cachedColor(forPicWithID picID: String) -> RGBColor? {
        let query = picColorsTable.filter(colorPicId == picID)
            .select(colorRed, colorGreen, colorBlue)
        guard let row = try? database.pluck(query),
              let red = try? row.get(colorRed),
              let green = try? row.get(colorGreen),
              let blue = try? row.get(colorBlue) else { return nil }
        return RGBColor(red: red, green: green, blue: blue)
    }

    func allCachedColors() -> [String: RGBColor] {
        let query = picColorsTable.select(colorPicId, colorRed, colorGreen, colorBlue)
        guard let rows = try? database.prepare(query) else { return [:] }
        var result: [String: RGBColor] = [:]
        for row in rows {
            guard let picID = try? row.get(colorPicId),
                  let red = try? row.get(colorRed),
                  let green = try? row.get(colorGreen),
                  let blue = try? row.get(colorBlue) else { continue }
            result[picID] = RGBColor(red: red, green: green, blue: blue)
        }
        return result
    }

    func cachedColors(forPicIDs picIDs: [String]) -> [String: RGBColor] {
        guard !picIDs.isEmpty else { return [:] }
        let placeholders = picIDs.map { _ in "?" }.joined(separator: ", ")
        let sql = "SELECT pic_id, red, green, blue FROM pic_colors WHERE pic_id IN (\(placeholders))"
        let bindings: [Binding?] = picIDs.map { $0 as Binding? }
        guard let stmt = try? database.prepare(sql, bindings) else { return [:] }
        var result: [String: RGBColor] = [:]
        for row in stmt {
            if let picID = row[0] as? String,
               let red = row[1] as? Int64,
               let green = row[2] as? Int64,
               let blue = row[3] as? Int64 {
                result[picID] = RGBColor(red: Int(red), green: Int(green), blue: Int(blue))
            }
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

    func storeColors(_ colors: [(picID: String, color: RGBColor)]) {
        guard !colors.isEmpty else { return }
        _ = try? database.transaction {
            for entry in colors {
                _ = try? database.run(picColorsTable.insert(or: .replace,
                    colorPicId <- entry.picID,
                    colorRed <- entry.color.red,
                    colorGreen <- entry.color.green,
                    colorBlue <- entry.color.blue
                ))
            }
        }
    }

    // MARK: - Delete

    func deleteColor(forPicWithID picID: String) {
        let query = picColorsTable.filter(colorPicId == picID)
        _ = try? database.run(query.delete())
    }

    func deleteColors(forPicIDs picIDs: [String]) {
        guard !picIDs.isEmpty else { return }
        let query = picColorsTable.filter(picIDs.contains(colorPicId))
        _ = try? database.run(query.delete())
    }

    func deleteAllColors() {
        _ = try? database.run(picColorsTable.delete())
    }
}
