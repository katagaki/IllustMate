//
//  DataActor+Preferences.swift
//  PicMate
//
//  Created by Claude on 2026/03/20.
//

import Foundation
@preconcurrency import SQLite

extension DataActor {

    func preferences(forAlbumWithID albumID: String) -> AlbumPreferences {
        let query = preferencesTable.filter(prefAlbumId == albumID)
        guard let row = try? database.pluck(query) else {
            return AlbumPreferences.defaults
        }
        return AlbumPreferences(
            albumID: (try? row.get(prefAlbumId)) ?? albumID,
            albumSort: (try? row.get(prefAlbumSort)) ?? AlbumPreferences.defaults.albumSort,
            albumViewStyle: (try? row.get(prefAlbumViewStyle)) ?? AlbumPreferences.defaults.albumViewStyle,
            albumColumnCount: (try? row.get(prefAlbumColumnCount)) ?? AlbumPreferences.defaults.albumColumnCount,
            picSort: (try? row.get(prefPicSort)) ?? AlbumPreferences.defaults.picSort,
            picColumnCount: (try? row.get(prefPicColumnCount)) ?? AlbumPreferences.defaults.picColumnCount
        )
    }

    func savePreferences(_ prefs: AlbumPreferences) {
        let query = preferencesTable.filter(prefAlbumId == prefs.albumID)
        if (try? database.pluck(query)) != nil {
            _ = try? database.run(query.update(
                prefAlbumSort <- prefs.albumSort,
                prefAlbumViewStyle <- prefs.albumViewStyle,
                prefAlbumColumnCount <- prefs.albumColumnCount,
                prefPicSort <- prefs.picSort,
                prefPicColumnCount <- prefs.picColumnCount
            ))
        } else {
            _ = try? database.run(preferencesTable.insert(
                prefAlbumId <- prefs.albumID,
                prefAlbumSort <- prefs.albumSort,
                prefAlbumViewStyle <- prefs.albumViewStyle,
                prefAlbumColumnCount <- prefs.albumColumnCount,
                prefPicSort <- prefs.picSort,
                prefPicColumnCount <- prefs.picColumnCount
            ))
        }
    }

    func deletePreferences(forAlbumWithID albumID: String) {
        let query = preferencesTable.filter(prefAlbumId == albumID)
        _ = try? database.run(query.delete())
    }

    func allAlbumIDs() -> [String] {
        let query = albumsTable.select(albumId)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { try? $0.get(albumId) }
    }

    func insertPreferencesForMigration(_ prefs: AlbumPreferences) {
        _ = try? database.run(preferencesTable.insert(or: .ignore,
            prefAlbumId <- prefs.albumID,
            prefAlbumSort <- prefs.albumSort,
            prefAlbumViewStyle <- prefs.albumViewStyle,
            prefAlbumColumnCount <- prefs.albumColumnCount,
            prefPicSort <- prefs.picSort,
            prefPicColumnCount <- prefs.picColumnCount
        ))
    }
}
