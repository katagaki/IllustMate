//
//  ImageMigrationManager.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//

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
    /// Thumbnail of the pic currently being migrated; sampled by the UI.
    var latestThumbnail: Data?

    /// Runs the migration for the active library if needed. Keeps the screen
    /// awake and blocks the UI for the duration. Safe to call on every library
    /// switch: it no-ops when already running or when nothing needs migrating.
    func runIfNeeded() async {
        guard !isMigrating else { return }
        guard await DataActor.shared.needsImageMigration() else { return }
        // Re-check after the await in case another caller started meanwhile.
        guard !isMigrating else { return }
        phase = .copying
        completed = 0
        total = 0
        latestThumbnail = nil
        isMigrating = true
        UIApplication.shared.isIdleTimerDisabled = true
        await DataActor.shared.migrateImageBlobsToFiles { progress in
            self.phase = progress.phase
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
