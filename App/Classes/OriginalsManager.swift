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
    private var reclaiming: Set<String> = []

    private let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")
    private let containerMarkerKey = "OriginalsContainerID"

    // MARK: - Paths

    private func libraryOriginalsDirectory(for collectionID: String) -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: Self.containerID)?
            .appendingPathComponent("Originals", isDirectory: true)
            .appendingPathComponent(collectionID, isDirectory: true)
    }

    private func originalsDirectory(for collectionID: String, mediaType: MediaType) -> URL? {
        let subfolder = mediaType == .video ? "Videos" : "Images"
        return libraryOriginalsDirectory(for: collectionID)?
            .appendingPathComponent(subfolder, isDirectory: true)
    }

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
        libraryOriginalsDirectory(for: collectionID)?.appendingPathComponent(id)
    }

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
        var url = url
        url.removeAllCachedResourceValues()
        return try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            .ubiquitousItemDownloadingStatus
    }

    // MARK: - Upload

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

    func reclaimUploadedOriginals(in collectionID: String, waitForUploads: Bool = true) async {
        guard !reclaiming.contains(collectionID) else { return }
        reclaiming.insert(collectionID)
        defer { reclaiming.remove(collectionID) }
        let dataActor = DataActor.instance(for: collectionID)
        var reclaimed = 0
        var consecutiveTimeouts = 0
        for id in await dataActor.localOriginalPicIDs() {
            guard let location = await dataActor.originalLocation(forPicWithID: id),
                  location.localURL != nil,
                  let cloudURL = cloudURL(forPicID: id, in: collectionID),
                  downloadingStatus(cloudURL) != nil else { continue }
            var uploaded = isUploaded(cloudURL)
            // Foreground only: wait for the just-mirrored original to finish uploading
            // before deleting the device-local copy, but stop once uploads clearly
            // aren't progressing (offline / paused) so this can't hang a large library.
            // Background sync never waits — it only reclaims already-uploaded copies.
            if !uploaded, waitForUploads, consecutiveTimeouts < 3 {
                uploaded = await waitForUpload(cloudURL)
                consecutiveTimeouts = uploaded ? 0 : consecutiveTimeouts + 1
            }
            guard uploaded else { continue }
            await dataActor.evictLocalOriginal(picID: id)
            reclaimed += 1
        }
        if reclaimed > 0 {
            await SyncMate.shared.debugLog("orig \(collectionID.prefix(4)): reclaimed \(reclaimed) local")
        }
    }

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

    private func isUploaded(_ url: URL) -> Bool {
        var url = url
        url.removeAllCachedResourceValues()
        return (try? url.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey]))?
            .ubiquitousItemIsUploaded ?? false
    }

    private func waitForUpload(_ url: URL, timeoutSeconds: Int = 8) async -> Bool {
        for _ in 0..<(timeoutSeconds * 2) {
            if isUploaded(url) { return true }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return isUploaded(url)
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

    private func coordinatedDelete(at url: URL) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                let coordinator = NSFileCoordinator()
                var coordinationError: NSError?
                coordinator.coordinate(
                    writingItemAt: url, options: .forDeleting, error: &coordinationError
                ) { deleteURL in
                    try? FileManager.default.removeItem(at: deleteURL)
                }
                continuation.resume()
            }
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

    /// The on-disk name of a pic's original in the ubiquity container (e.g. `<id>.mov` for videos,
    /// the bare id for images). Used to drive the download-progress query, which matches by filename.
    func cloudOriginalFilename(picID: String, in collectionID: String) -> String? {
        cloudURL(forPicID: picID, in: collectionID)?.lastPathComponent
    }

    func originalSize(picID: String, in collectionID: String) async -> Int64? {
        guard let url = cloudURL(forPicID: picID, in: collectionID) else { return nil }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey])
        if let total = values?.totalFileSize { return Int64(total) }
        if let size = values?.fileSize { return Int64(size) }
        return nil
    }

    // MARK: - Delete

    func deleteCloudOriginal(picID: String, in collectionID: String) async {
        guard isUbiquityAvailable(),
              let cloudURL = cloudURL(forPicID: picID, in: collectionID) else { return }
        await coordinatedDelete(at: cloudURL)
    }

    func deleteCloudOriginals(picIDs: [String], in collectionID: String) async {
        for id in picIDs {
            await deleteCloudOriginal(picID: id, in: collectionID)
        }
    }

    func deleteAllOriginals(in collectionID: String) async {
        guard isUbiquityAvailable(),
              let directory = libraryOriginalsDirectory(for: collectionID) else { return }
        await coordinatedDelete(at: directory)
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
