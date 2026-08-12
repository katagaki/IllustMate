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

    // An evicted ubiquitous item exists on disk only as a ".<name>.icloud" placeholder;
    // resource-value queries against the bare path throw, which reads as "no such item".
    // Resolve per call so the URL flips back once a download replaces the placeholder.
    func placeholderAwareURL(_ url: URL) -> URL {
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let placeholder = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).icloud")
        return FileManager.default.fileExists(atPath: placeholder.path) ? placeholder : url
    }

    func requestDownload(_ url: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: placeholderAwareURL(url))
    }

    // Direct resource-value reads fail for cloud-only items that fileproviderd has not
    // materialized locally; a coordinated read with .immediatelyAvailableMetadataOnly
    // asks the file provider for the item's metadata without downloading it.
    func cloudResourceValues(at url: URL, keys: Set<URLResourceKey>) -> URLResourceValues? {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var values: URLResourceValues?
        coordinator.coordinate(readingItemAt: placeholderAwareURL(url),
                               options: .immediatelyAvailableMetadataOnly,
                               error: &coordinationError) { readURL in
            var readURL = readURL
            readURL.removeAllCachedResourceValues()
            values = try? readURL.resourceValues(forKeys: keys)
        }
        return values
    }

    func downloadingStatus(_ url: URL) -> URLUbiquitousItemDownloadingStatus? {
        cloudResourceValues(at: url, keys: [.ubiquitousItemDownloadingStatusKey])?
            .ubiquitousItemDownloadingStatus
    }
}
