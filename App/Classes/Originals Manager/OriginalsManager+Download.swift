import Foundation

extension OriginalsManager {

    private func isMaterialized(_ url: URL) -> Bool {
        downloadingStatus(url) == .current
    }

    @discardableResult
    func materializeOriginal(picID: String, in collectionID: String) async -> Bool {
        guard let url = cloudURL(forPicID: picID, in: collectionID) else { return false }
        if isMaterialized(url) { return true }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        return await waitForDownload(url)
    }

    func picIDsNotMaterialized(in collectionID: String) async -> [String] {
        let ids = await DataActor.instance(for: collectionID).allOriginalPicIDs()
        return ids.filter { id in
            guard let url = cloudURL(forPicID: id, in: collectionID) else { return false }
            return !isMaterialized(url)
        }
    }

    func downloadAllOriginals(in collectionID: String) async {
        let ids = await DataActor.instance(for: collectionID).allOriginalPicIDs()
        for id in ids {
            guard let url = cloudURL(forPicID: id, in: collectionID), !isMaterialized(url) else { continue }
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }

    func startAlbumOfflineDownloads(albumID: String, in collectionID: String) async {
        let ids = await DataActor.instance(for: collectionID).allOriginalPicIDs(inAlbum: albumID)
        for id in ids {
            guard let url = cloudURL(forPicID: id, in: collectionID), !isMaterialized(url) else { continue }
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }

    func keepAlbumOffline(albumID: String, in collectionID: String) async {
        let allIDs = await DataActor.instance(for: collectionID).allOriginalPicIDs(inAlbum: albumID)
        let pending = allIDs.filter { id in
            guard let url = cloudURL(forPicID: id, in: collectionID) else { return false }
            return !isMaterialized(url)
        }
        guard !pending.isEmpty else { return }
        await postAlbumProgress(albumID, fraction: 0)
        var done = 0
        for id in pending {
            await materializeOriginal(picID: id, in: collectionID)
            done += 1
            await postAlbumProgress(albumID, fraction: Double(done) / Double(pending.count))
        }
        await postAlbumProgress(albumID, fraction: nil)
    }

    private func postAlbumProgress(_ albumID: String, fraction: Double?) async {
        await MainActor.run {
            var info: [String: Any] = ["albumID": albumID]
            if let fraction { info["fraction"] = fraction }
            NotificationCenter.default.post(name: Notification.Name("OfflineAlbumDownloadProgress"),
                                            object: nil, userInfo: info)
        }
    }

    func removeAlbumDownload(albumID: String, in collectionID: String) async {
        let dataActor = DataActor.instance(for: collectionID)
        for id in await dataActor.localOriginalPicIDs(inAlbum: albumID) {
            guard let cloudURL = cloudURL(forPicID: id, in: collectionID), isUploaded(cloudURL) else {
                continue
            }
            await dataActor.evictLocalOriginal(picID: id)
            try? FileManager.default.evictUbiquitousItem(at: cloudURL)
        }
    }

    func fetchOriginal(picID: String, in collectionID: String) async -> Data? {
        guard let cloudURL = cloudURL(forPicID: picID, in: collectionID) else {
            await SyncMate.shared.debugLog("fetch: no container")
            return nil
        }
        try? FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)
        guard await waitForDownload(cloudURL) else {
            await SyncMate.shared.debugLog("fetch \(picID.prefix(6)): timeout \(statusLabel(cloudURL))")
            return nil
        }
        guard let data = await coordinatedReadData(at: cloudURL) else {
            await SyncMate.shared.debugLog("fetch \(picID.prefix(6)): read fail")
            return nil
        }
        await SyncMate.shared.debugLog("fetch \(picID.prefix(6)): ok \(data.count / 1024)KB")
        return data
    }

    func materializedVideoURL(picID: String, in collectionID: String) async -> URL? {
        guard let url = cloudURL(forPicID: picID, in: collectionID) else {
            await SyncMate.shared.debugLog("video \(picID.prefix(6)): no container")
            return nil
        }
        if isMaterialized(url) { return url }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        if await waitForDownload(url) {
            await SyncMate.shared.debugLog("video \(picID.prefix(6)): ok")
            return url
        }
        await SyncMate.shared.debugLog("video \(picID.prefix(6)): timeout \(statusLabel(url))")
        return nil
    }

    private func waitForDownload(_ url: URL, timeoutSeconds: Int = 10) async -> Bool {
        for _ in 0..<(timeoutSeconds * 2) {
            if downloadingStatus(url) == .current { return true }
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            try? await Task.sleep(for: .milliseconds(500))
        }
        return downloadingStatus(url) == .current
    }

    private func statusLabel(_ url: URL) -> String {
        downloadingStatus(url)?.rawValue
            .replacingOccurrences(of: "NSURLUbiquitousItemDownloadingStatus", with: "") ?? "unknown"
    }
}
