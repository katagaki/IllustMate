//
//  DataActor+Sync.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//
//  Local sync bookkeeping: records that mutate are flagged `dirty` with a
//  `last_modified` timestamp, and deletions leave a tombstone, so a later
//  CloudKit sync engine can push only what changed. No network here.
//

import Foundation
@preconcurrency import SQLite

enum SyncRecordType {
    static let pic = "Pic"
    static let album = "Album"
}

extension DataActor {

    /// Current time as a Unix timestamp, for `last_modified` bookkeeping.
    var syncTimestamp: Double { Date.now.timeIntervalSince1970 }

    /// Records a deletion so it can be propagated to other devices.
    func recordTombstone(id: String, recordType: String) {
        _ = try? database.run(tombstonesTable.insert(or: .replace,
            tombstoneId <- id,
            tombstoneRecordType <- recordType,
            tombstoneDeletedAt <- syncTimestamp
        ))
    }

    func recordTombstones(ids: [String], recordType: String) {
        for id in ids {
            recordTombstone(id: id, recordType: recordType)
        }
    }
}
