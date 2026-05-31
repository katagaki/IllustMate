import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class ImageMigrationManager {

    var isMigrating: Bool = false
    var phase: ImageMigrationPhase = .preparing
    var completed: Int = 0
    var total: Int = 0
    var latestThumbnail: Data?

    func runPendingMigrations() async {
        guard !isMigrating else { return }
        guard DatabaseMigrator.needsLibraryV2Migration() else { return }
        // Present the cover up front. Scanning each library to learn whether it
        // needs migrating takes time, and the collection UI behind us renders
        // against half-migrated data during that check. Showing the cover
        // immediately keeps that broken state hidden while we determine what (if
        // anything) actually needs to be migrated.
        beginMigration()
        for id in await LibrariesActor.shared.allLibraryIDs() {
            await migrate(libraryID: id)
        }
        DatabaseMigrator.markLibraryV2MigrationComplete()
        endMigration()
    }

    func runIfNeeded(for libraryID: String) async {
        guard !isMigrating else { return }
        let dataActor = DataActor.instance(for: libraryID)
        // Only reveal the cover once we know this library genuinely needs work,
        // so switching between already-migrated libraries never flashes it.
        guard await !dataActor.isLibraryV2MigrationComplete() else {
            await LibrariesActor.shared.setLibraryMigrated(true, forID: libraryID)
            return
        }
        beginMigration()
        await migrate(libraryID: libraryID, dataActor: dataActor, alreadyChecked: true)
        endMigration()
    }

    private func migrate(libraryID: String,
                         dataActor: DataActor? = nil,
                         alreadyChecked: Bool = false) async {
        let dataActor = dataActor ?? DataActor.instance(for: libraryID)
        if !alreadyChecked, await dataActor.isLibraryV2MigrationComplete() {
            await LibrariesActor.shared.setLibraryMigrated(true, forID: libraryID)
            return
        }
        phase = .copying
        completed = 0
        total = 0
        latestThumbnail = nil
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
    }

    private func beginMigration() {
        phase = .preparing
        completed = 0
        total = 0
        latestThumbnail = nil
        isMigrating = true
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func endMigration() {
        UIApplication.shared.isIdleTimerDisabled = false
        isMigrating = false
    }
}
