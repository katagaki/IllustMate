import Foundation

enum LastUsedAlbum {

    private static let key = "LastUsedMoveDestinationAlbumID"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")
    }

    static var id: String? {
        guard let value = defaults?.string(forKey: key), !value.isEmpty else { return nil }
        return value
    }

    static func set(_ albumID: String) {
        defaults?.set(albumID, forKey: key)
    }

    static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
