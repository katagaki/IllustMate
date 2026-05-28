//
//  OriginalsManager.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//

import Foundation

actor OriginalsManager {

    static let shared = OriginalsManager()
    static let containerID = "iCloud.com.tsubuzaki.IllustMateSQLite"

    /// `Documents/Originals` inside the iCloud Drive ubiquity container.
    private func originalsDirectory() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: Self.containerID)?
            .appendingPathComponent("Documents/Originals", isDirectory: true)
    }

    private func originalURL(forPicID id: String) -> URL? {
        originalsDirectory()?.appendingPathComponent(id)
    }

    /// Download state of an item, or nil if it isn't in iCloud at all.
    private func downloadingStatus(_ url: URL) -> URLUbiquitousItemDownloadingStatus? {
        try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            .ubiquitousItemDownloadingStatus
    }

    /// Mirrors a pic's local original into iCloud Drive (idempotent). The source
    /// device calls this once its metadata record has been uploaded.
    func uploadOriginal(picID: String) async {
        guard let cloudURL = originalURL(forPicID: picID),
              let directory = originalsDirectory() else { return }
        // Already in iCloud (downloaded or as a placeholder)?
        if downloadingStatus(cloudURL) != nil { return }
        guard let localURL = await DataActor.shared.localOriginalURL(forPicWithID: picID) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.copyItem(at: localURL, to: cloudURL)
    }

    /// Fetches a pic's original from iCloud Drive (downloading it if needed),
    /// caches it locally, and returns the bytes. Nil if it isn't available.
    func fetchOriginal(picID: String) async -> Data? {
        guard let cloudURL = originalURL(forPicID: picID),
              let status = downloadingStatus(cloudURL) else { return nil }
        if status == .notDownloaded {
            try? FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)
            guard await waitForDownload(cloudURL) else { return nil }
        }
        guard let data = try? Data(contentsOf: cloudURL) else { return nil }
        await DataActor.shared.importDownloadedOriginal(picID: picID, data: data)
        // Keep only the local Images cache; the original stays in iCloud.
        evictOriginal(picID: picID)
        return data
    }

    /// Removes the local copy of an original, keeping it in iCloud (Optimize
    /// Storage). It re-downloads on next access.
    func evictOriginal(picID: String) {
        guard let cloudURL = originalURL(forPicID: picID) else { return }
        try? FileManager.default.evictUbiquitousItem(at: cloudURL)
    }

    private func waitForDownload(_ url: URL, timeoutSeconds: Int = 60) async -> Bool {
        for _ in 0..<(timeoutSeconds * 2) {
            if let status = downloadingStatus(url), status != .notDownloaded { return true }
            try? await Task.sleep(for: .milliseconds(500))
        }
        let status = downloadingStatus(url) ?? .notDownloaded
        return status != .notDownloaded
    }
}
