import Foundation

@MainActor
final class SyncManager {

    static let shared = SyncManager()

    func canEnableSync() async -> Bool {
        guard await SyncMate.shared.isAccountAvailable() else { return false }
        return await OriginalsManager.shared.isUbiquityAvailable()
    }

    func refresh() async {
        for id in await LibrariesActor.shared.unmigratedLibraryIDs() {
            if await DataActor.instance(for: id).isLibraryV2MigrationComplete() {
                await LibrariesActor.shared.setLibraryMigrated(true, forID: id)
            }
        }

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
        let enabled = Set(enabledIDs)
        for (albumID, collectionID) in OfflineAlbums.all() where enabled.contains(collectionID) {
            Task.detached(priority: .utility) {
                await OriginalsManager.shared.keepAlbumOffline(albumID: albumID, in: collectionID)
            }
        }
    }
}
