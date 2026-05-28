//
//  ImageMigrationManager.swift
//  PicMate
//
//  Drives the one-time image-blob externalization migration and exposes its
//  progress to the blocking migration UI.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class ImageMigrationManager {

    var isMigrating: Bool = false
    var completed: Int = 0
    var total: Int = 0
    /// Thumbnail of the pic currently being migrated; sampled by the UI.
    var latestThumbnail: Data?

    /// Runs the migration for the active library if needed. Keeps the screen
    /// awake and blocks the UI for the duration.
    func runIfNeeded() async {
        guard await DataActor.shared.needsImageMigration() else { return }
        completed = 0
        total = 0
        latestThumbnail = nil
        isMigrating = true
        UIApplication.shared.isIdleTimerDisabled = true
        await DataActor.shared.migrateImageBlobsToFiles { progress in
            self.completed = progress.completed
            self.total = progress.total
            if let thumbnail = progress.latestThumbnail {
                self.latestThumbnail = thumbnail
            }
        }
        UIApplication.shared.isIdleTimerDisabled = false
        isMigrating = false
    }
}
