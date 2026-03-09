//
//  DataActor+Hashes.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/09.
//

import Foundation
@preconcurrency import SQLite

extension DataActor {

    /// Fetch all pic IDs in the database.
    func allPicIDs() -> [String] {
        let query = picsTable.select(picId)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { try? $0.get(picId) }
    }

    /// Fetch pic IDs in a specific album.
    func picIDs(inAlbumWithID albumID: String) -> [String] {
        let query = picsTable.filter(picAlbumId == albumID).select(picId)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { try? $0.get(picId) }
    }

    /// Fetch pic IDs that are not assigned to any album.
    func picIDsNotInAnyAlbum() -> [String] {
        let query = picsTable.filter(picAlbumId == nil).select(picId)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { try? $0.get(picId) }
    }

    /// Fetch a single Pic skeleton by ID (no image blob data).
    func pic(forID picID: String) -> Pic? {
        let query = picsTable
            .filter(picId == picID)
            .select(picId, picName, picAlbumId, picDateAdded, picThumbnailData)
        guard let row = try? database.pluck(query) else { return nil }
        return picFrom(row: row)
    }
}
