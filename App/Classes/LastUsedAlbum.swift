import Foundation

enum LastUsedAlbum {

    private static let key = "LastUsedMoveDestinationAlbumIDs"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")
    }

    private static func all() -> [String: String] {
        defaults?.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    static func id(in collectionID: String) -> String? {
        guard let value = all()[collectionID], !value.isEmpty else { return nil }
        return value
    }

    static func set(_ albumID: String, in collectionID: String) {
        var map = all()
        map[collectionID] = albumID
        defaults?.set(map, forKey: key)
    }

    static func clear(in collectionID: String) {
        var map = all()
        map[collectionID] = nil
        defaults?.set(map, forKey: key)
    }
}
