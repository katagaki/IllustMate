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
            try FileManager.default.copyItem(at: localURL, to: cloudURL)
            await dataActor.markPicOriginalSynced(id: picID)
            return .uploaded
        } catch {
            return .failed(error.localizedDescription)
        }
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

    /// Fetches a pic's original from iCloud Drive (downloading it if needed),
    /// caches it locally, and returns the bytes. Nil if it isn't available.
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
        guard let data = try? Data(contentsOf: cloudURL) else {
            await SyncMate.shared.debugLog("fetch \(picID.prefix(6)): read fail")
            return nil
        }
        await DataActor.instance(for: collectionID).importDownloadedOriginal(picID: picID, data: data)
        // The bytes now live in the local Images cache; drop the iCloud copy.
        evictOriginal(picID: picID, in: collectionID)
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
