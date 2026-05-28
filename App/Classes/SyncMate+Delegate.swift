//
//  SyncMate+Delegate.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//
//  CKSyncEngineDelegate: builds CKRecords for upload, applies fetched changes
//  to the matching library's DataActor, and resolves conflicts last-writer-wins.
//

@preconcurrency import CloudKit
import Foundation

extension SyncMate: CKSyncEngineDelegate {

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            saveState(update.stateSerialization)
        case .fetchedRecordZoneChanges(let changes):
            await applyFetchedRecordZoneChanges(changes)
        case .sentRecordZoneChanges(let changes):
            await handleSentRecordZoneChanges(changes, syncEngine: syncEngine)
        case .accountChange(let change):
            handleAccountChange(change)
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !pending.isEmpty else { return nil }

        // Build records up front (DB access is async); drop saves whose record
        // no longer exists locally.
        var records: [CKRecord.ID: CKRecord] = [:]
        for change in pending {
            if case .saveRecord(let recordID) = change {
                if let record = await buildRecord(for: recordID) {
                    records[recordID] = record
                } else {
                    syncEngine.state.remove(pendingRecordZoneChanges: [change])
                }
            }
        }
        let builtRecords = records
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            builtRecords[recordID]
        }
    }

    // MARK: - Build records (upload)

    private func buildRecord(for recordID: CKRecord.ID) async -> CKRecord? {
        let collectionID = Self.collectionID(forZone: recordID.zoneID)
        let dataActor = DataActor.instance(for: collectionID)
        let name = recordID.recordName
        if let album = await dataActor.albumSyncSnapshot(forID: name) {
            return albumRecord(from: album, recordID: recordID)
        }
        if let pic = await dataActor.picSyncSnapshot(forID: name) {
            return picRecord(from: pic, recordID: recordID)
        }
        return nil
    }

    private func albumRecord(from snapshot: AlbumSyncSnapshot, recordID: CKRecord.ID) -> CKRecord {
        let record = baseRecord(snapshot.systemFields, recordID: recordID, type: SyncRecordType.album)
        record["name"] = snapshot.name
        record["parentAlbumID"] = snapshot.parentAlbumID
        record["dateCreated"] = Date(timeIntervalSince1970: snapshot.dateCreated)
        return record
    }

    private func picRecord(from snapshot: PicSyncSnapshot, recordID: CKRecord.ID) -> CKRecord {
        let record = baseRecord(snapshot.systemFields, recordID: recordID, type: SyncRecordType.pic)
        record["name"] = snapshot.name
        record["containingAlbumID"] = snapshot.albumID
        record["dateAdded"] = Date(timeIntervalSince1970: snapshot.dateAdded)
        record["mediaType"] = snapshot.mediaType
        record["duration"] = snapshot.duration
        record["thumbnail"] = snapshot.thumbnail
        return record
    }

    private func baseRecord(_ systemFields: Data?, recordID: CKRecord.ID, type: String) -> CKRecord {
        if let systemFields, let record = Self.decodeSystemFields(systemFields) {
            return record
        }
        return CKRecord(recordType: type, recordID: recordID)
    }

    // MARK: - Apply fetched changes (download)

    private func applyFetchedRecordZoneChanges(
        _ changes: CKSyncEngine.Event.FetchedRecordZoneChanges
    ) async {
        for modification in changes.modifications {
            await applyRecord(modification.record)
        }
        for deletion in changes.deletions {
            let dataActor = DataActor.instance(for: Self.collectionID(forZone: deletion.recordID.zoneID))
            if deletion.recordType == SyncRecordType.album {
                await dataActor.removeAlbumForRemoteDelete(id: deletion.recordID.recordName)
            } else {
                await dataActor.removePicForRemoteDelete(id: deletion.recordID.recordName)
            }
        }
    }

    private func applyRecord(_ record: CKRecord) async {
        let dataActor = DataActor.instance(for: Self.collectionID(forZone: record.recordID.zoneID))
        let systemFields = Self.encodeSystemFields(record)
        let modified = (record.modificationDate ?? Date.now).timeIntervalSince1970
        if record.recordType == SyncRecordType.album {
            await dataActor.applyRemoteAlbum(AlbumSyncSnapshot(
                id: record.recordID.recordName,
                name: record["name"] as? String ?? "",
                parentAlbumID: record["parentAlbumID"] as? String,
                dateCreated: (record["dateCreated"] as? Date)?.timeIntervalSince1970 ?? 0,
                systemFields: systemFields,
                lastModified: modified
            ))
        } else if record.recordType == SyncRecordType.pic {
            await dataActor.applyRemotePic(PicSyncSnapshot(
                id: record.recordID.recordName,
                name: record["name"] as? String ?? "",
                albumID: record["containingAlbumID"] as? String,
                dateAdded: (record["dateAdded"] as? Date)?.timeIntervalSince1970 ?? 0,
                mediaType: record["mediaType"] as? Int ?? 0,
                duration: record["duration"] as? Double,
                thumbnail: record["thumbnail"] as? Data,
                systemFields: systemFields,
                lastModified: modified
            ))
        }
    }

    // MARK: - Handle sent changes

    private func handleSentRecordZoneChanges(
        _ changes: CKSyncEngine.Event.SentRecordZoneChanges,
        syncEngine: CKSyncEngine
    ) async {
        for record in changes.savedRecords {
            let dataActor = DataActor.instance(for: Self.collectionID(forZone: record.recordID.zoneID))
            let systemFields = Self.encodeSystemFields(record)
            if record.recordType == SyncRecordType.album {
                await dataActor.markAlbumSynced(id: record.recordID.recordName, systemFields: systemFields)
            } else {
                await dataActor.markPicSynced(id: record.recordID.recordName, systemFields: systemFields)
            }
        }
        for recordID in changes.deletedRecordIDs {
            await DataActor.instance(for: Self.collectionID(forZone: recordID.zoneID))
                .removeTombstone(id: recordID.recordName)
        }
        for failure in changes.failedRecordSaves {
            await handleFailedSave(failure, syncEngine: syncEngine)
        }
    }

    private func handleFailedSave(
        _ failure: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave,
        syncEngine: CKSyncEngine
    ) async {
        let recordID = failure.record.recordID
        let error = failure.error
        if error.code == .serverRecordChanged,
           let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
            // Last-writer-wins: accept the server's version.
            await applyRecord(serverRecord)
        } else if error.code == .zoneNotFound {
            syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: recordID.zoneID))])
            syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        }
        // Otherwise transient: the record stays dirty and retries on the next sync.
    }

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signOut, .switchAccounts:
            clearState()
        default:
            break
        }
    }

    // MARK: - System fields (de)serialization

    static func encodeSystemFields(_ record: CKRecord) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        return archiver.encodedData
    }

    static func decodeSystemFields(_ data: Data) -> CKRecord? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        let record = CKRecord(coder: unarchiver)
        unarchiver.finishDecoding()
        return record
    }
}
