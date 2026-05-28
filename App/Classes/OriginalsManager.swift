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
    static let containerID = "iCloud.com.tsubuzaki.IllustMate"

    private var uploadingMissing: Set<String> = []

    private let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")
    private let containerMarkerKey = "OriginalsContainerID"

    // MARK: - Paths

    /// App-private `Originals/<library>/<Images|Videos>` folder in the iCloud
    /// Drive ubiquity container. Kept outside `Documents/` so it isn't exposed in
    /// the Files app, split per library and per media kind, while syncing over iCloud.
    private func originalsDirectory(for collectionID: String, mediaType: MediaType) -> URL? {
        let subfolder = mediaType == .video ? "Videos" : "Images"
        return FileManager.default.url(forUbiquityContainerIdentifier: Self.containerID)?
            .appendingPathComponent("Originals", isDirectory: true)
            .appendingPathComponent(collectionID, isDirectory: true)
            .appendingPathComponent(subfolder, isDirectory: true)
    }

    /// iCloud URL of a pic's original, resolved without a database lookup: image
    /// originals are stored under their bare ID, video originals keep their
    /// extension and are located by listing the Videos folder for `id.*`. Falls
    /// back to the pre-split `Originals/<library>/<id>` layout for older uploads.
    private func cloudURL(forPicID id: String, in collectionID: String) -> URL? {
        if let imagesDirectory = originalsDirectory(for: collectionID, mediaType: .pic) {
            let imageURL = imagesDirectory.appendingPathComponent(id)
            if downloadingStatus(imageURL) != nil { return imageURL }
        }
        if let videosDirectory = originalsDirectory(for: collectionID, mediaType: .video),
           let videoURL = enumerateVideoOriginal(in: videosDirectory, picID: id) {
            return videoURL
        }
        if let legacyURL = legacyOriginalURL(forPicID: id, in: collectionID),
           downloadingStatus(legacyURL) != nil {
            return legacyURL
        }
        return originalsDirectory(for: collectionID, mediaType: .pic)?.appendingPathComponent(id)
    }

    private func legacyOriginalURL(forPicID id: String, in collectionID: String) -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: Self.containerID)?
            .appendingPathComponent("Originals", isDirectory: true)
            .appendingPathComponent(collectionID, isDirectory: true)
            .appendingPathComponent(id)
    }

    /// Locates a video original by pic ID, tolerating undownloaded
    /// `.id.ext.icloud` placeholder names that iCloud uses before materialization.
    private func enumerateVideoOriginal(in directory: URL, picID: String) -> URL? {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return nil }
        for url in items {
            var name = url.lastPathComponent
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                name = String(name.dropFirst().dropLast(".icloud".count))
            }
            if (name as NSString).deletingPathExtension == picID {
                return directory.appendingPathComponent(name)
            }
        }
        return nil
    }

    func isUbiquityAvailable() -> Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: Self.containerID) != nil
    }

    private func downloadingStatus(_ url: URL) -> URLUbiquitousItemDownloadingStatus? {
        try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            .ubiquitousItemDownloadingStatus
    }

    // MARK: - Upload

    /// Mirrors a pic's local original (image or video) into iCloud Drive
    /// (idempotent) and marks it synced. Called reactively after a metadata
    /// record uploads, and by the consistency pass for anything the cloud is missing.
    @discardableResult
    func uploadOriginal(picID: String, in collectionID: String) async -> OriginalUploadOutcome {
        let dataActor = DataActor.instance(for: collectionID)
        guard let location = await dataActor.originalLocation(forPicWithID: picID) else {
            return .noLocalFile
        }
        guard let directory = originalsDirectory(for: collectionID, mediaType: location.mediaType) else {
            return .noContainer
        }
        guard let filename = location.filename else { return .noLocalFile }
        let cloudURL = directory.appendingPathComponent(filename)
        if downloadingStatus(cloudURL) != nil {
            await dataActor.markPicOriginalSynced(id: picID)
            return .alreadyPresent
        }
        guard let localURL = location.localURL else { return .noLocalFile }
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

    /// Mirrors every local original not yet in iCloud Drive for a library, healing
    /// originals the reactive path missed and migrating local videos into iCloud.
    func uploadMissingOriginals(in collectionID: String) async {
        guard !uploadingMissing.contains(collectionID) else { return }
        uploadingMissing.insert(collectionID)
        defer { uploadingMissing.remove(collectionID) }
        let dataActor = DataActor.instance(for: collectionID)
        let ids = await dataActor.picIDsNeedingOriginalUpload()
        await SyncMate.shared.debugLog("orig \(collectionID.prefix(4)): \(ids.count) to mirror")
        guard !ids.isEmpty else { return }
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

    /// Once an original is confirmed uploaded, frees its local master so a synced
    /// library relies on iCloud. Image paths are cleared; video paths are kept so
    /// the extension stays known. Gated on `isUploaded`, never deleting the last copy.
    func reclaimUploadedOriginals(in collectionID: String) async {
        let dataActor = DataActor.instance(for: collectionID)
        for id in await dataActor.localOriginalPicIDs() {
            guard let location = await dataActor.originalLocation(forPicWithID: id),
                  location.localURL != nil,
                  let cloudURL = cloudURL(forPicID: id, in: collectionID),
                  isUploaded(cloudURL) else { continue }
            await dataActor.evictLocalOriginal(picID: id)
        }
    }

    /// When the originals container changes, every pic's upload flag is stale, so
    /// clear it across all libraries to re-upload into the new container.
    func resetSyncStateIfContainerChanged() async {
        guard defaults?.string(forKey: containerMarkerKey) != Self.containerID else { return }
        for id in await LibrariesActor.shared.allLibraryIDs() {
            await DataActor.instance(for: id).resetOriginalSyncState()
        }
        defaults?.set(Self.containerID, forKey: containerMarkerKey)
        await SyncMate.shared.debugLog("orig: container changed, reset upload flags")
    }

    // MARK: - Download

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

    /// Downloads an album's originals that aren't already materialized (Keep
    /// Offline), posting progress so the cover can show a donut.
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

    /// Notifies album covers of offline-download progress. The observer name is
    /// duplicated in AlbumGridLabel, which ships in the extension target.
    private func postAlbumProgress(_ albumID: String, fraction: Double?) async {
        await MainActor.run {
            var info: [String: Any] = ["albumID": albumID]
            if let fraction { info["fraction"] = fraction }
            NotificationCenter.default.post(name: Notification.Name("OfflineAlbumDownloadProgress"),
                                            object: nil, userInfo: info)
        }
    }

    /// Frees the local copies of an album's originals (Remove Download), keeping
    /// thumbnails. Only evicts once iCloud confirms the upload.
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

    private func isUploaded(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey]))?
            .ubiquitousItemIsUploaded ?? false
    }

    // MARK: - Coordinated I/O

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

    /// Reads an image original from the iCloud Drive container, downloading it if
    /// needed. iCloud manages local materialization and eviction.
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

    /// Downloads a video original from iCloud Drive and returns a playable file
    /// URL. Used when this device has no local copy (reclaimed or synced-in).
    func materializedVideoURL(picID: String, in collectionID: String) async -> URL? {
        guard let url = cloudURL(forPicID: picID, in: collectionID) else { return nil }
        if isMaterialized(url) { return url }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        return await waitForDownload(url) ? url : nil
    }

    func evictOriginal(picID: String, in collectionID: String) {
        guard let cloudURL = cloudURL(forPicID: picID, in: collectionID) else { return }
        try? FileManager.default.evictUbiquitousItem(at: cloudURL)
    }

    private func waitForDownload(_ url: URL, timeoutSeconds: Int = 30) async -> Bool {
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
