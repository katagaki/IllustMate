//
//  OriginalsManager.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//

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
    /// iCloud Drive ubiquity container holding full-resolution originals.
    /// CloudKit metadata syncs separately through SyncMate's own container.
    static let containerID = "iCloud.com.tsubuzaki.IllustMate"

    /// Libraries with an in-flight `uploadMissingOriginals` pass, so repeated
    /// sync triggers don't stack redundant scans.
    private var uploadingMissing: Set<String> = []

    private let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")
    private let containerMarkerKey = "OriginalsContainerID"

    /// App-private `Originals/<library>` folder in the iCloud Drive ubiquity
    /// container. Kept outside `Documents/` so it isn't exposed in the Files
    /// app, and split per library, while still syncing over iCloud.
    private func originalsDirectory(for collectionID: String) -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: Self.containerID)?
            .appendingPathComponent("Originals", isDirectory: true)
            .appendingPathComponent(collectionID, isDirectory: true)
    }

    private func originalURL(forPicID id: String, in collectionID: String) -> URL? {
        originalsDirectory(for: collectionID)?.appendingPathComponent(id)
    }

    /// True if iCloud Drive is enabled (the ubiquity container is reachable).
    func isUbiquityAvailable() -> Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: Self.containerID) != nil
    }

    /// Download state of an item, or nil if it isn't in iCloud at all.
    private func downloadingStatus(_ url: URL) -> URLUbiquitousItemDownloadingStatus? {
        try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            .ubiquitousItemDownloadingStatus
    }

    /// Mirrors a pic's local original into iCloud Drive (idempotent) and marks it
    /// synced. Called both reactively (after the metadata record uploads) and by
    /// the consistency pass for any original the cloud is still missing.
    @discardableResult
    func uploadOriginal(picID: String, in collectionID: String) async -> OriginalUploadOutcome {
        guard let cloudURL = originalURL(forPicID: picID, in: collectionID),
              let directory = originalsDirectory(for: collectionID) else { return .noContainer }
        let dataActor = DataActor.instance(for: collectionID)
        // Already in iCloud (downloaded or as a placeholder)?
        if downloadingStatus(cloudURL) != nil {
            await dataActor.markPicOriginalSynced(id: picID)
            return .alreadyPresent
        }
        guard let localURL = await dataActor.localOriginalURL(forPicWithID: picID) else {
            return .noLocalFile
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return .failed(error.localizedDescription)
        }
        guard await coordinatedCopy(from: localURL, to: cloudURL) else {
            return .failed("coordinated write failed")
        }
        await dataActor.markPicOriginalSynced(id: picID)
        return .uploaded
    }

    /// Mirrors every local original not yet in iCloud Drive for a library. Heals
    /// originals the reactive path missed (e.g. pics synced before this existed).
    func uploadMissingOriginals(in collectionID: String) async {
        guard !uploadingMissing.contains(collectionID) else { return }
        uploadingMissing.insert(collectionID)
        defer { uploadingMissing.remove(collectionID) }
        let dataActor = DataActor.instance(for: collectionID)
        let ids = await dataActor.picIDsNeedingOriginalUpload()
        await SyncMate.shared.debugLog("orig \(collectionID.prefix(4)): \(ids.count) to mirror")
        guard !ids.isEmpty else {
            let diag = await dataActor.originalUploadDiagnostics()
            await SyncMate.shared.debugLog("orig diag: \(diag.images)img \(diag.withPath)path \(diag.needUpload)need")
            return
        }
        var up = 0, present = 0, noLocal = 0, failed = 0, noCont = 0
        var sampleError: String?
        for id in ids {
            switch await uploadOriginal(picID: id, in: collectionID) {
            case .uploaded: up += 1
            case .alreadyPresent: present += 1
            case .noContainer: noCont += 1
            case .noLocalFile: noLocal += 1
            case .failed(let message):
                failed += 1
                if sampleError == nil { sampleError = message }
            }
        }
        await SyncMate.shared.debugLog("orig done: \(up)up \(present)pre \(noLocal)noloc \(failed)err \(noCont)noc")
        if let sampleError { await SyncMate.shared.debugLog("orig err: \(sampleError)") }
    }

    /// Once an original is confirmed fully uploaded to iCloud, deletes its local
    /// master so a synced library relies on iCloud for storage (reading on demand
    /// from the container). Gated on `isUploaded`, so the original is never the
    /// last copy deleted. Only synced-library originals are in the container, so
    /// non-synced libraries are untouched.
    func reclaimUploadedOriginals(in collectionID: String) async {
        let dataActor = DataActor.instance(for: collectionID)
        for id in await dataActor.localImagePicIDs() {
            guard let cloudURL = originalURL(forPicID: id, in: collectionID), isUploaded(cloudURL) else {
                continue
            }
            await dataActor.evictLocalOriginal(picID: id)
        }
    }

    /// When the originals container changes, every pic's stored upload flag is
    /// stale (it points at the old container), so clear it across all libraries
    /// so originals re-upload into the new container. Runs once per change.
    func resetSyncStateIfContainerChanged() async {
        guard defaults?.string(forKey: containerMarkerKey) != Self.containerID else { return }
        for id in await LibrariesActor.shared.allLibraryIDs() {
            await DataActor.instance(for: id).resetOriginalSyncState()
        }
        defaults?.set(Self.containerID, forKey: containerMarkerKey)
        await SyncMate.shared.debugLog("orig: container changed, reset upload flags")
    }

    /// True once the container item is materialized locally (the most current
    /// version is downloaded), i.e. the original is available offline.
    private func isMaterialized(_ url: URL) -> Bool {
        downloadingStatus(url) == .current
    }

    /// Downloads an original into the container without reading its bytes, so it's
    /// available offline. Returns true once it's materialized (or already was).
    @discardableResult
    func materializeOriginal(picID: String, in collectionID: String) async -> Bool {
        guard let url = originalURL(forPicID: picID, in: collectionID) else { return false }
        if isMaterialized(url) { return true }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        return await waitForDownload(url)
    }

    /// Image pics in a library whose original isn't downloaded locally yet.
    func picIDsNotMaterialized(in collectionID: String) async -> [String] {
        let ids = await DataActor.instance(for: collectionID).imagePicIDs()
        return ids.filter { id in
            guard let url = originalURL(forPicID: id, in: collectionID) else { return false }
            return !isMaterialized(url)
        }
    }

    /// Requests materialization of every original not already downloaded for a
    /// library (Download All). iCloud downloads them in the background.
    func downloadAllOriginals(in collectionID: String) async {
        let ids = await DataActor.instance(for: collectionID).imagePicIDs()
        for id in ids {
            guard let url = originalURL(forPicID: id, in: collectionID), !isMaterialized(url) else { continue }
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }

    /// Downloads an album's originals that aren't already materialized (Keep
    /// Offline), posting progress so the cover can show a donut. If everything is
    /// already offline, nothing is downloaded and no donut is shown.
    func keepAlbumOffline(albumID: String, in collectionID: String) async {
        let allIDs = await DataActor.instance(for: collectionID).imagePicIDs(inAlbum: albumID)
        let pending = allIDs.filter { id in
            guard let url = originalURL(forPicID: id, in: collectionID) else { return false }
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

    /// Notifies album covers of offline-download progress. The observer is in
    /// AlbumGridLabel; the name is duplicated there because that view ships in
    /// the extension target and can't import App code.
    private func postAlbumProgress(_ albumID: String, fraction: Double?) async {
        await MainActor.run {
            var info: [String: Any] = ["albumID": albumID]
            if let fraction { info["fraction"] = fraction }
            NotificationCenter.default.post(name: Notification.Name("OfflineAlbumDownloadProgress"),
                                            object: nil, userInfo: info)
        }
    }

    /// Frees the local copies of an album's originals (Remove Download), keeping
    /// thumbnails. Only evicts an original once iCloud confirms it's uploaded, so
    /// the full-resolution copy is never the last one standing.
    func removeAlbumDownload(albumID: String, in collectionID: String) async {
        let dataActor = DataActor.instance(for: collectionID)
        let ids = await dataActor.localImagePicIDs(inAlbum: albumID)
        for id in ids {
            guard let cloudURL = originalURL(forPicID: id, in: collectionID), isUploaded(cloudURL) else {
                continue
            }
            await dataActor.evictLocalOriginal(picID: id)
            try? FileManager.default.evictUbiquitousItem(at: cloudURL)
        }
    }

    /// True only once iCloud reports the item as fully uploaded.
    private func isUploaded(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey]))?
            .ubiquitousItemIsUploaded ?? false
    }

    /// Copies a file into the iCloud container under file coordination, so the
    /// iCloud daemon reliably notices and uploads it. The blocking coordinator
    /// runs off the actor so it never stalls other sync work.
    private func coordinatedCopy(from source: URL, to destination: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let coordinator = NSFileCoordinator()
                var coordinationError: NSError?
                var success = false
                coordinator.coordinate(
                    writingItemAt: destination, options: .forReplacing, error: &coordinationError
                ) { writeURL in
                    do {
                        if FileManager.default.fileExists(atPath: writeURL.path) {
                            try FileManager.default.removeItem(at: writeURL)
                        }
                        try FileManager.default.copyItem(at: source, to: writeURL)
                        success = true
                    } catch {
                        success = false
                    }
                }
                continuation.resume(returning: success && coordinationError == nil)
            }
        }
    }

    /// Reads an iCloud item under file coordination, so we never read a
    /// partially-materialized file. Runs off the actor.
    private func coordinatedReadData(at url: URL) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let coordinator = NSFileCoordinator()
                var coordinationError: NSError?
                var data: Data?
                coordinator.coordinate(
                    readingItemAt: url, options: [], error: &coordinationError
                ) { readURL in
                    data = try? Data(contentsOf: readURL)
                }
                continuation.resume(returning: data)
            }
        }
    }

    /// Reads a pic's original straight from the iCloud Drive container
    /// (downloading it if needed) and returns the bytes, without keeping a
    /// separate local copy — iCloud manages local materialization and eviction.
    func fetchOriginal(picID: String, in collectionID: String) async -> Data? {
        guard let cloudURL = originalURL(forPicID: picID, in: collectionID) else {
            await SyncMate.shared.debugLog("fetch: no container")
            return nil
        }
        // A device that received this file from another device may not have a
        // materialized placeholder yet, so request the download unconditionally
        // rather than giving up when the status is still unknown.
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

    /// Removes the local copy of an original, keeping it in iCloud (Optimize
    /// Storage). It re-downloads on next access.
    func evictOriginal(picID: String, in collectionID: String) {
        guard let cloudURL = originalURL(forPicID: picID, in: collectionID) else { return }
        try? FileManager.default.evictUbiquitousItem(at: cloudURL)
    }

    private func waitForDownload(_ url: URL, timeoutSeconds: Int = 30) async -> Bool {
        for _ in 0..<(timeoutSeconds * 2) {
            if downloadingStatus(url) == .current { return true }
            // Re-request: the item may only become known after the container syncs.
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            try? await Task.sleep(for: .milliseconds(500))
        }
        return downloadingStatus(url) == .current
    }

    /// Short human-readable iCloud download status, for debug logging.
    private func statusLabel(_ url: URL) -> String {
        downloadingStatus(url)?.rawValue
            .replacingOccurrences(of: "NSURLUbiquitousItemDownloadingStatus", with: "") ?? "unknown"
    }
}
