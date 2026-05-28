//
//  SyncManager.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//

import Foundation

@MainActor
final class SyncManager {

    static let shared = SyncManager()

    /// Sync can only be enabled when signed into iCloud and iCloud Drive is on.
    func canEnableSync() async -> Bool {
        guard await SyncMate.shared.isAccountAvailable() else { return false }
        return await OriginalsManager.shared.isUbiquityAvailable()
    }

    /// Starts (or stops) sync to match per-library settings, and pushes/pulls
    /// changes for every sync-enabled library. Safe to call repeatedly.
    func refresh() async {
        let enabledIDs = await LibrariesActor.shared.syncEnabledLibraryIDs()
        #if DEBUG
        SyncDebugMonitor.shared.enabled = !enabledIDs.isEmpty
        #endif
        guard !enabledIDs.isEmpty else {
            await SyncMate.shared.stop()
            return
        }
        await SyncMate.shared.start()
        await SyncMate.shared.reportAccountStatus()
        await SyncMate.shared.enqueueLibraryChanges()
        for id in enabledIDs {
            await SyncMate.shared.enqueueChanges(forLibrary: id)
        }
        await SyncMate.shared.fetchChanges()
        // If the originals container changed, re-upload originals into the new one.
        await OriginalsManager.shared.resetSyncStateIfContainerChanged()
        // Mirror any originals the cloud is still missing, off the main actor.
        for id in enabledIDs {
            Task.detached(priority: .utility) {
                await OriginalsManager.shared.uploadMissingOriginals(in: id)
            }
        }
    }
}
