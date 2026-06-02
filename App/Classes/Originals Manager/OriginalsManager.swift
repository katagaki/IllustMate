import Foundation

enum OriginalUploadOutcome: Sendable {
    case uploaded
    case alreadyPresent
    case noContainer
    case noLocalFile
    case failed(String)
}

actor OriginalsManager {

    static let shared = OriginalsManager()
    static let containerID = "iCloud.com.tsubuzaki.IllustMate"

    var uploadingMissing: Set<String> = []
    var reclaiming: Set<String> = []

    let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")
    let containerMarkerKey = "OriginalsContainerID"

    func isUbiquityAvailable() -> Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: Self.containerID) != nil
    }

    func downloadingStatus(_ url: URL) -> URLUbiquitousItemDownloadingStatus? {
        var url = url
        url.removeAllCachedResourceValues()
        return try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            .ubiquitousItemDownloadingStatus
    }
}
