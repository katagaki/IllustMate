//
//  DataActor+ImageMigration.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//

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

    /// True if any image pic still has its bytes stored as a BLOB.
    func needsImageMigration() -> Bool {
        let query = picsTable.filter(picMediaType == MediaType.pic.rawValue && picData != nil)
        return ((try? database.scalar(query.count)) ?? 0) > 0
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
                if verifyMigratedFile(id: id) { verifiedIDs.append(id) }
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
