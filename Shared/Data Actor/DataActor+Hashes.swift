import Foundation
@preconcurrency import SQLite

extension DataActor {

    func allPicIDs() -> [String] {
        let query = picsTable.select(picId)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { try? $0.get(picId) }
    }

    func picIDs(inAlbumWithID albumID: String) -> [String] {
        let query = picsTable.filter(picAlbumId == albumID).select(picId)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { try? $0.get(picId) }
    }

    func picIDsNotInAnyAlbum() -> [String] {
        let query = picsTable.filter(picAlbumId == nil).select(picId)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { try? $0.get(picId) }
    }

    func pic(forID picID: String) -> Pic? {
        let query = picsTable
            .filter(picId == picID)
            .select(picId, picName, picAlbumId, picDateAdded, picThumbnailData)
        guard let row = try? database.pluck(query) else { return nil }
        return picFrom(row: row)
    }
}
