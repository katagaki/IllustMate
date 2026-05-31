import CryptoKit
import Foundation
@preconcurrency import SQLite

/// Stage the migration is currently in (drives the on-screen status label).
enum ImageMigrationPhase: Sendable {
    case copying
    case verifying
    case reclaiming
}

/// Progress snapshot for the migration UI. `total == 0` indicates an
/// indeterminate phase (e.g. the final VACUUM, which reports no progress).
struct ImageMigrationProgress: Sendable {
    let phase: ImageMigrationPhase
    let completed: Int
    let total: Int
    let latestThumbnail: Data?
}

extension DataActor {

    /// Identifies the image-blob externalization migration in the per-library
    /// `migrations` table.
    static let libraryV2MigrationName = "LibraryV2"

    func needsImageMigration() -> Bool {
        let query = picsTable.filter(picMediaType == MediaType.pic.rawValue && picData != nil)
        return ((try? database.scalar(query.count)) ?? 0) > 0
    }

    /// Whether this library has finished the LibraryV2 image-blob migration.
    /// A library with nothing left to migrate is marked complete on the spot,
    /// so freshly created or synced-in libraries report complete immediately
    /// (and become eligible for sync) without a UI pass.
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

    /// Externalizes every image BLOB to a file. Safe to call repeatedly and to
    /// interrupt: state is derived from the DB (a pic is done once its blob is
    /// null and its file exists), so re-running resumes where it left off.
    func migrateImageBlobsToFiles(
        progress: @escaping @MainActor (ImageMigrationProgress) -> Void
    ) async {
        let pending = pendingMigrationIDs()
        let total = pending.count
        guard total > 0 else { return }
        // Show the total up front so the UI isn't stuck on 0/0.
        await progress(ImageMigrationProgress(phase: .copying, completed: 0,
                                              total: total, latestThumbnail: nil))

        let batchSize = chosenBatchSize(total: total)
        let singleBatch = batchSize >= total
        // The per-batch `incremental_vacuum` only frees pages once the database
        // is actually in INCREMENTAL auto-vacuum mode; convert up front (while no
        // files exist yet) so the multi-batch path can keep peak disk bounded.
        if !singleBatch { ensureIncrementalVacuumActive() }
        var copied = 0
        var verified = 0
        var start = 0
        while start < pending.count {
            let batch = Array(pending[start..<min(start + batchSize, pending.count)])
            // Stage 1 — copy (blob -> file, blob left intact).
            for id in batch {
                copyBlobToFile(id: id)
                copied += 1
                await progress(ImageMigrationProgress(phase: .copying, completed: copied,
                                                      total: total,
                                                      latestThumbnail: thumbnailData(forPicWithID: id)))
            }
            // Stage 2 — verify file hashes against the still-present blobs.
            var verifiedIDs: [String] = []
            for id in batch {
                if verifyMigratedFile(id: id) {
                    verifiedIDs.append(id)
                } else {
                    // Don't leave file_path pointing at an unverified file: the
                    // blob is still present and authoritative, and imageData
                    // would otherwise prefer the bad file over the good blob.
                    revertMigratedFile(id: id)
                }
                verified += 1
                await progress(ImageMigrationProgress(phase: .verifying, completed: verified,
                                                      total: total,
                                                      latestThumbnail: thumbnailData(forPicWithID: id)))
            }
            // Stage 3 — finalize: only now null the verified blobs.
            for id in verifiedIDs {
                _ = try? database.run(picsTable.filter(picId == id).update(picData <- nil))
            }
            if !singleBatch {
                await progress(ImageMigrationProgress(phase: .reclaiming, completed: 0,
                                                      total: 0, latestThumbnail: nil))
                reclaimSpaceIncrementally()
            }
            start += batchSize
        }
        // Reclaim the freed pages back to the filesystem (indeterminate).
        await progress(ImageMigrationProgress(phase: .reclaiming, completed: 0,
                                              total: 0, latestThumbnail: nil))
        // Let the UI render the reclaiming spinner before VACUUM blocks the actor.
        try? await Task.sleep(for: .seconds(1))
        vacuum()
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

    /// Undoes a failed externalization: removes the stray file and clears the
    /// path so the still-present blob remains the pic's source of truth. This
    /// keeps the invariant `file_path set ⇒ verified`, which `imageData` relies
    /// on when it prefers the file over the blob.
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

    /// Chooses a batch size so the externalized files for one batch fit in free
    /// space: a single batch when free > 2× the library, otherwise roughly
    /// `ceil(librarySize / freeSpace)` batches, degrading to one-by-one when
    /// space is very tight.
    private func chosenBatchSize(total: Int) -> Int {
        let free = availableFreeBytes()
        let payload = currentDatabaseFileSize()
        guard payload > 0, free > 0 else { return total }
        if free > 2 * payload { return total }
        let averageEntry = payload / Int64(max(total, 1))
        if free < averageEntry * 2 { return 1 }
        let batchCount = max(2, Int((Double(payload) / Double(free)).rounded(.up)))
        return max(1, Int((Double(total) / Double(batchCount)).rounded(.up)))
    }

    private func availableFreeBytes() -> Int64 {
        let values = try? databaseURL.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        return values?.volumeAvailableCapacityForImportantUsage ?? Int64.max
    }

    private func currentDatabaseFileSize() -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: databaseURL.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// No-op unless the database is in incremental auto-vacuum mode.
    private func reclaimSpaceIncrementally() {
        _ = try? database.execute("PRAGMA incremental_vacuum;")
    }

    /// `PRAGMA incremental_vacuum` reclaims nothing unless the database is in
    /// INCREMENTAL auto-vacuum mode, and a database created before that mode was
    /// set keeps its original mode until a full `VACUUM` rewrites it. Without
    /// this conversion the per-batch reclaim would be a silent no-op during the
    /// very migration that needs it, defeating the batching that bounds peak
    /// disk usage. Convert once up front, only when the conversion fits in free
    /// space (no externalized files exist yet, so peak use is ~2× the database).
    private func ensureIncrementalVacuumActive() {
        // 2 == SQLITE_AUTO_VACUUM_INCREMENTAL.
        guard let mode = (try? database.scalar("PRAGMA auto_vacuum")) as? Int64,
              mode != 2 else { return }
        guard currentDatabaseFileSize() < availableFreeBytes() else { return }
        _ = try? database.execute("PRAGMA auto_vacuum = INCREMENTAL;")
        _ = try? database.vacuum()
    }
}

#if DEBUG
extension DataActor {
    /// Inserts a legacy blob-backed image pic (bytes stored in the `data`
    /// column, no file). Used by the sample-data seeder's `legacy` mode so the
    /// image-blob migration can be exercised within a single build.
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
#endif
