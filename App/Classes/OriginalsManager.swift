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
    static let containerID = "iCloud.com.tsubuzaki.IllustMateSQLite"

    /// Libraries with an in-flight `uploadMissingOriginals` pass, so repeated
    /// sync triggers don't stack redundant scans.
    private var uploadingMissing: Set<String> = []

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

    /// Fetches a pic's original from iCloud Drive (downloading it if needed),
    /// caches it locally, and returns the bytes. Nil if it isn't available.
    func fetchOriginal(picID: String, in collectionID: String) async -> Data? {
        guard let cloudURL = originalURL(forPicID: picID, in: collectionID),
              let status = downloadingStatus(cloudURL) else { return nil }
        if status == .notDownloaded {
            try? FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)
            guard await waitForDownload(cloudURL) else { return nil }
        }
        guard let data = try? Data(contentsOf: cloudURL) else { return nil }
        await DataActor.instance(for: collectionID).importDownloadedOriginal(picID: picID, data: data)
        // Keep only the local Images cache; the original stays in iCloud.
        evictOriginal(picID: picID, in: collectionID)
        return data
    }

    /// Removes the local copy of an original, keeping it in iCloud (Optimize
    /// Storage). It re-downloads on next access.
    func evictOriginal(picID: String, in collectionID: String) {
        guard let cloudURL = originalURL(forPicID: picID, in: collectionID) else { return }
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
