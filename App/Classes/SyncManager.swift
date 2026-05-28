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
    static let flagKey = "iCloudSyncEnabled"

    private let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")

    var isEnabled: Bool { defaults?.bool(forKey: Self.flagKey) ?? false }

    /// Starts (or stops) sync to match the setting and pushes/pulls changes for
    /// the active library. Safe to call repeatedly.
    func refresh(activeLibraryID: String) async {
        #if DEBUG
        SyncDebugMonitor.shared.enabled = isEnabled
        #endif
        guard isEnabled else {
            await SyncMate.shared.stop()
            return
        }
        await SyncMate.shared.start()
        await SyncMate.shared.reportAccountStatus()
        await SyncMate.shared.enqueueLibraryChanges()
        await SyncMate.shared.enqueueChanges(forLibrary: activeLibraryID)
        await SyncMate.shared.fetchChanges()
    }
}
