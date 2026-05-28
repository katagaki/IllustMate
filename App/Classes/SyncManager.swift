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
        await OriginalsManager.shared.resetSyncStateIfContainerChanged()
        for id in enabledIDs {
            Task.detached(priority: .utility) {
                await OriginalsManager.shared.uploadMissingOriginals(in: id)
                await OriginalsManager.shared.reclaimUploadedOriginals(in: id)
            }
        }
        for id in await LibrariesActor.shared.downloadAllLibraryIDs() {
            Task.detached(priority: .utility) {
                await OriginalsManager.shared.downloadAllOriginals(in: id)
            }
        }
        // Keep-Offline albums: pull their originals (also catches later additions).
        let enabled = Set(enabledIDs)
        for (albumID, collectionID) in OfflineAlbums.all() where enabled.contains(collectionID) {
            Task.detached(priority: .utility) {
                await OriginalsManager.shared.keepAlbumOffline(albumID: albumID, in: collectionID)
            }
        }
    }
}
