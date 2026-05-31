import Foundation

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
