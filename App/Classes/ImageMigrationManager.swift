import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class ImageMigrationManager {

    var isMigrating: Bool = false
    var phase: ImageMigrationPhase = .copying
    var completed: Int = 0
    var total: Int = 0
    var latestThumbnail: Data?

    /// Migrates every library that hasn't completed the LibraryV2 image-blob
    /// migration, then records global completion so the sweep runs only once.
    /// Per-library state is the source of truth (each library's `migrations`
    /// table), so an interrupted sweep resumes where it left off on next start.
    /// Safe to call repeatedly.
    func runPendingMigrations() async {
        guard !isMigrating else { return }
        guard DatabaseMigrator.needsLibraryV2Migration() else { return }
        for id in await LibrariesActor.shared.allLibraryIDs() {
            await migrate(libraryID: id)
        }
        DatabaseMigrator.markLibraryV2MigrationComplete()
    }

    /// Migrates a single library if it isn't already done. Used when switching
    /// libraries, and as a safeguard for libraries that arrive after the global
    /// sweep has completed. No-ops when the library is already migrated.
    func runIfNeeded(for libraryID: String) async {
        guard !isMigrating else { return }
        await migrate(libraryID: libraryID)
    }

    /// Keeps the screen awake and blocks the UI only while a library actually
    /// has blobs to externalize; libraries with nothing to do are marked
    /// complete silently. Drives the registry's `migrated_v2` mirror so sync
    /// stays gated on real migration state.
    private func migrate(libraryID: String) async {
        let dataActor = DataActor.instance(for: libraryID)
        if await dataActor.isLibraryV2MigrationComplete() {
            await LibrariesActor.shared.setLibraryMigrated(true, forID: libraryID)
            return
        }
        // Re-check after the awaits above in case another caller started meanwhile.
        guard !isMigrating else { return }
        phase = .copying
        completed = 0
        total = 0
        latestThumbnail = nil
        isMigrating = true
        UIApplication.shared.isIdleTimerDisabled = true
        await dataActor.migrateImageBlobsToFiles { progress in
            self.phase = progress.phase
            self.completed = progress.completed
            self.total = progress.total
            if let thumbnail = progress.latestThumbnail {
                self.latestThumbnail = thumbnail
            }
        }
        await dataActor.markLibraryV2MigrationComplete()
        await LibrariesActor.shared.setLibraryMigrated(true, forID: libraryID)
        UIApplication.shared.isIdleTimerDisabled = false
        isMigrating = false
    }
}
