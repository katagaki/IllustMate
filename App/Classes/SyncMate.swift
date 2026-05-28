//
//  SyncMate.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//
//  Owns a single CKSyncEngine for the private CloudKit database and syncs
//  album/pic *metadata* (no originals yet — those are fetched on demand in a
//  later step). One CloudKit zone per library; downloads are routed to the
//  matching library's DataActor.
//

@preconcurrency import CloudKit
import Foundation

extension Notification.Name {
    /// Posted (on the main actor) after sync applies remote record changes,
    /// so data-backed views can refresh.
    static let syncDidApplyRemoteChanges = Notification.Name("SyncDidApplyRemoteChanges")
}

actor SyncMate {

    static let shared = SyncMate()
    static let containerID = "iCloud.com.tsubuzaki.IllustMateSQLite"

    private let container: CKContainer
    private var engine: CKSyncEngine?
    private let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")
    private let stateKey = "CKSyncEngineState"

    init() {
        container = CKContainer(identifier: Self.containerID)
    }

    var isRunning: Bool { engine != nil }

    /// Creates the sync engine (idempotent). Pending changes the engine had
    /// persisted resume automatically from the saved state.
    func start() {
        guard engine == nil else { return }
        let configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: loadState(),
            delegate: self
        )
        engine = CKSyncEngine(configuration)
    }

    func stop() {
        engine = nil
    }

    /// Scans a library for dirty records and tombstones and queues them for
    /// upload (also ensuring the library's zone exists).
    func enqueueChanges(forLibrary collectionID: String) async {
        guard let engine else { return }
        let zoneID = Self.zoneID(for: collectionID)
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])

        let dataActor = DataActor.instance(for: collectionID)
        let albumIDs = await dataActor.dirtyAlbumIDs()
        let picIDs = await dataActor.dirtyPicIDs()
        let tombstones = await dataActor.pendingTombstones()

        var pending: [CKSyncEngine.PendingRecordZoneChange] = []
        for id in albumIDs + picIDs {
            pending.append(.saveRecord(CKRecord.ID(recordName: id, zoneID: zoneID)))
        }
        for tombstone in tombstones {
            pending.append(.deleteRecord(CKRecord.ID(recordName: tombstone.id, zoneID: zoneID)))
        }
        await debugLog("scan \(albumIDs.count)A \(picIDs.count)P \(tombstones.count)del")
        guard !pending.isEmpty else { return }
        engine.state.add(pendingRecordZoneChanges: pending)
    }

    /// Pulls remote changes immediately (e.g. on foreground).
    func fetchChanges() async {
        guard let engine else { return }
        try? await engine.fetchChanges()
    }

    // MARK: - Zone <-> library mapping

    static func zoneName(for collectionID: String) -> String {
        collectionID == PicLibrary.defaultID ? "DefaultLibrary" : "Library-\(collectionID)"
    }

    static func zoneID(for collectionID: String) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName(for: collectionID), ownerName: CKCurrentUserDefaultName)
    }

    static func collectionID(forZone zoneID: CKRecordZone.ID) -> String {
        let name = zoneID.zoneName
        if name == "DefaultLibrary" { return PicLibrary.defaultID }
        if name.hasPrefix("Library-") { return String(name.dropFirst("Library-".count)) }
        return PicLibrary.defaultID
    }

    // MARK: - State persistence

    private func loadState() -> CKSyncEngine.State.Serialization? {
        guard let data = defaults?.data(forKey: stateKey) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    func saveState(_ state: CKSyncEngine.State.Serialization) {
        defaults?.set(try? JSONEncoder().encode(state), forKey: stateKey)
    }

    func clearState() {
        defaults?.removeObject(forKey: stateKey)
    }

    // MARK: - Debug

    func debugLog(_ message: String) async {
        #if DEBUG
        await SyncDebugMonitor.shared.log(message)
        #endif
    }

    func reportAccountStatus() async {
        #if DEBUG
        let status = (try? await container.accountStatus()) ?? .couldNotDetermine
        await SyncDebugMonitor.shared.setAccount(Self.describe(status))
        #endif
    }

    #if DEBUG
    private static func describe(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: "available"
        case .noAccount: "no account"
        case .restricted: "restricted"
        case .couldNotDetermine: "unknown"
        case .temporarilyUnavailable: "unavailable"
        @unknown default: "unknown"
        }
    }
    #endif
}
