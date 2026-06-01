import CryptoKit
import Foundation
@preconcurrency import SQLite

enum ImageMigrationPhase: Sendable {
    case preparing
    case copying
    case verifying
    case reclaiming
}

struct ImageMigrationProgress: Sendable {
    let phase: ImageMigrationPhase
    let completed: Int
    let total: Int
    let latestThumbnail: Data?
}

extension DataActor {

    static let libraryV2MigrationName = "LibraryV2"

    func needsImageMigration() -> Bool {
        let query = picsTable.filter(picMediaType == MediaType.pic.rawValue && picData != nil)
        return ((try? database.scalar(query.count)) ?? 0) > 0
    }

    func isLibraryV2MigrationComplete() -> Bool {
        if migrationCompletedFlag(Self.libraryV2MigrationName) { return true }
        guard needsImageMigration() else {
            markLibraryV2MigrationComplete()
            return true
        }
        return false
    }

    func markLibraryV2MigrationComplete() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        _ = try? database.run(migrationsTable.insert(or: .replace,
            migrationName <- Self.libraryV2MigrationName,
            migrationAppVersion <- version,
            migrationCompleted <- true
        ))
    }

    private func migrationCompletedFlag(_ name: String) -> Bool {
        let query = migrationsTable.filter(migrationName == name)
        guard let row = try? database.pluck(query) else { return false }
        return (try? row.get(migrationCompleted)) ?? false
    }

    func migrateImageBlobsToFiles(
        progress: @escaping @MainActor (ImageMigrationProgress) -> Void
    ) async {
        let pending = pendingMigrationIDs()
        let total = pending.count
        guard total > 0 else { return }
        await progress(ImageMigrationProgress(phase: .copying, completed: 0,
                                              total: total, latestThumbnail: nil))

        let batchSize = chosenBatchSize(total: total)
        let singleBatch = batchSize >= total
        ensureIncrementalAutoVacuum()
        var copied = 0
        var verified = 0
        var start = 0
        while start < pending.count {
            let batch = Array(pending[start..<min(start + batchSize, pending.count)])
            for id in batch {
                copyBlobToFile(id: id)
                copied += 1
                await progress(ImageMigrationProgress(phase: .copying, completed: copied,
                                                      total: total,
                                                      latestThumbnail: thumbnailData(forPicWithID: id)))
            }
            var verifiedIDs: [String] = []
            for id in batch {
                if verifyMigratedFile(id: id) {
                    verifiedIDs.append(id)
                } else {
                    revertMigratedFile(id: id)
                }
                verified += 1
                await progress(ImageMigrationProgress(phase: .verifying, completed: verified,
                                                      total: total,
                                                      latestThumbnail: thumbnailData(forPicWithID: id)))
            }
            for id in verifiedIDs {
                do {
                    try database.run(picsTable.filter(picId == id).update(picData <- nil))
                } catch {
                    debugPrint("Failed to clear migrated blob for \(id): \(error)")
                }
            }
            if !singleBatch {
                await progress(ImageMigrationProgress(phase: .reclaiming, completed: 0,
                                                      total: 0, latestThumbnail: nil))
                reclaimSpaceIncrementally()
            }
            start += batchSize
        }
        await progress(ImageMigrationProgress(phase: .reclaiming, completed: 0,
                                              total: 0, latestThumbnail: nil))
        try? await Task.sleep(for: .seconds(1))
        if !reclaimDiskSpace() {
            debugPrint("Image migration: final disk space reclamation freed no space")
        }
    }

    @discardableResult
    func purgeMigratedBlobs() -> Int {
        guard isLibraryV2MigrationComplete() else { return 0 }
        let query = picsTable
            .filter(picFilePath != nil && picData != nil)
            .select(picId)
        let ids = (try? database.prepare(query).map { $0[picId] }) ?? []
        var purged = 0
        for id in ids where verifyMigratedFile(id: id) {
            do {
                try database.run(picsTable.filter(picId == id).update(picData <- nil))
                purged += 1
            } catch {
                debugPrint("Failed to purge migrated blob for \(id): \(error)")
            }
        }
        return purged
    }

    // MARK: - Helpers

    private func pendingMigrationIDs() -> [String] {
        let query = picsTable
            .filter(picMediaType == MediaType.pic.rawValue && picData != nil)
            .select(picId)
        return (try? database.prepare(query).map { $0[picId] }) ?? []
    }

    private func copyBlobToFile(id: String) {
        guard let blob = rawBlobData(forPicWithID: id), !blob.isEmpty,
              let relativePath = saveImageFile(blob, id: id) else { return }
        _ = try? database.run(picsTable.filter(picId == id).update(picFilePath <- relativePath))
    }

    private func revertMigratedFile(id: String) {
        let query = picsTable.filter(picId == id).select(picFilePath)
        if let row = try? database.pluck(query),
           let path = (try? row.get(picFilePath)) ?? nil {
            deleteImageFile(atRelativePath: path)
        }
        _ = try? database.run(picsTable.filter(picId == id).update(picFilePath <- nil))
    }

    private func verifyMigratedFile(id: String) -> Bool {
        guard let blob = rawBlobData(forPicWithID: id) else { return false }
        let query = picsTable.filter(picId == id).select(picFilePath)
        guard let row = try? database.pluck(query),
              let path = try? row.get(picFilePath),
              let fileData = try? Data(contentsOf: imageFileURL(forRelativePath: path)) else {
            return false
        }
        return SHA256.hash(data: fileData) == SHA256.hash(data: blob)
    }

    private func chosenBatchSize(total: Int) -> Int {
        let free = freeBytesAtDatabaseLocation()
        let payload = databaseFileSizeBytes()
        guard payload > 0, free > 0 else { return total }
        if free > 2 * payload { return total }
        let averageEntry = payload / Int64(max(total, 1))
        if free < averageEntry * 2 { return 1 }
        let batchCount = max(2, Int((Double(payload) / Double(free)).rounded(.up)))
        return max(1, Int((Double(total) / Double(batchCount)).rounded(.up)))
    }

    private func reclaimSpaceIncrementally() {
        // incremental_vacuum is a no-op outside incremental mode.
        guard autoVacuumMode() == 2 else { return }
        do {
            try database.execute("PRAGMA incremental_vacuum;")
        } catch {
            debugPrint("Incremental vacuum failed: \(error)")
        }
    }
}

extension DataActor {
    func createImageBlobPic(_ name: String, data: Data,
                            inAlbumWithID albumID: String? = nil, dateAdded: Date? = nil) {
        let id = UUID().uuidString
        let now = dateAdded ?? Date.now
        _ = try? database.run(picsTable.insert(
            picId <- id,
            picName <- name,
            picAlbumId <- albumID,
            picDateAdded <- now.timeIntervalSince1970,
            picData <- data,
            picThumbnailData <- Pic.makeThumbnail(data),
            picMediaType <- MediaType.pic.rawValue
        ))
    }
}
