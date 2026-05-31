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

    func runPendingMigrations() async {
        guard !isMigrating else { return }
        guard DatabaseMigrator.needsLibraryV2Migration() else { return }
        for id in await LibrariesActor.shared.allLibraryIDs() {
            await migrate(libraryID: id)
        }
        DatabaseMigrator.markLibraryV2MigrationComplete()
    }

    func runIfNeeded(for libraryID: String) async {
        guard !isMigrating else { return }
        await migrate(libraryID: libraryID)
    }

    private func migrate(libraryID: String) async {
        let dataActor = DataActor.instance(for: libraryID)
        if await dataActor.isLibraryV2MigrationComplete() {
            await LibrariesActor.shared.setLibraryMigrated(true, forID: libraryID)
            return
        }
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
