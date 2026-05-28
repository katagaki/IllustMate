//
//  OfflineAlbums.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//

import Foundation

/// Device-local registry of albums pinned for offline access (not synced).
/// Maps an album ID to the library (collection) it belongs to, so the sync
/// refresh can keep their originals downloaded.
enum OfflineAlbums {

    private static let key = "KeptOfflineAlbums"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")
    }

    static func all() -> [String: String] {
        defaults?.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    static func contains(_ albumID: String) -> Bool {
        all()[albumID] != nil
    }

    static func add(_ albumID: String, in collectionID: String) {
        var map = all()
        map[albumID] = collectionID
        defaults?.set(map, forKey: key)
    }

    static func remove(_ albumID: String) {
        var map = all()
        map[albumID] = nil
        defaults?.set(map, forKey: key)
    }

    /// Flips an album's offline state and starts the matching download/eviction.
    static func toggle(_ albumID: String, in collectionID: String) {
        if contains(albumID) {
            remove(albumID)
            Task { await OriginalsManager.shared.removeAlbumDownload(albumID: albumID, in: collectionID) }
        } else {
            add(albumID, in: collectionID)
            Task { await OriginalsManager.shared.keepAlbumOffline(albumID: albumID, in: collectionID) }
        }
    }
}
