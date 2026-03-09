//
//  DuplicateScanManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/09.
//

import Foundation
import UIKit

struct DuplicateGroup: Identifiable {
    let id = UUID()
    var pics: [Pic]
}

@MainActor @Observable
class DuplicateScanManager {

    // Scan state
    var isScanning: Bool = false
    var scanProgress: Int = 0
    var scanTotal: Int = 0
    var scanPhase: ScanPhase = .idle

    // Results
    var duplicateGroups: [DuplicateGroup] = []

    // Configuration
    var hammingThreshold: Int = 10

    enum ScanPhase {
        case idle
        case computingHashes
        case comparingHashes
        case done
    }

    func scan(album: Album?) async {
        isScanning = true
        scanPhase = .computingHashes
        scanProgress = 0
        duplicateGroups = []

        // Get all pic IDs in scope
        let allScopedIDs: [String]
        if let album {
            allScopedIDs = await DataActor.shared.picIDs(inAlbumWithID: album.id)
        } else {
            allScopedIDs = await DataActor.shared.allPicIDs()
        }

        // Find which ones don't have cached hashes
        let cachedIDs = await HashActor.shared.picIDsWithCachedHash()
        let uncachedIDs = allScopedIDs.filter { !cachedIDs.contains($0) }

        scanTotal = uncachedIDs.count

        // Phase 1: Compute hashes for uncached pics
        for picID in uncachedIDs {
            if let data = await DataActor.shared.imageData(forPicWithID: picID),
               let image = UIImage(data: data),
               let hash = DHash.compute(from: image) {
                await HashActor.shared.storeHash(hash, forPicWithID: picID)
            }
            scanProgress += 1
        }

        // Phase 2: Load all hashes for scoped pics and group by similarity
        scanPhase = .comparingHashes

        let allHashes = await HashActor.shared.allCachedHashes()
        let scopedIDSet = Set(allScopedIDs)
        let scopedHashes = allHashes.filter { scopedIDSet.contains($0.0) }

        let groups = findDuplicateGroups(hashes: scopedHashes, threshold: hammingThreshold)

        // Convert to DuplicateGroup with Pic objects
        var resultGroups: [DuplicateGroup] = []
        for group in groups where group.count >= 2 {
            var pics: [Pic] = []
            for (picID, _) in group {
                if let pic = await DataActor.shared.pic(forID: picID) {
                    pics.append(pic)
                }
            }
            if pics.count >= 2 {
                let sortedPics = pics.sorted { $0.dateAdded < $1.dateAdded }
                resultGroups.append(DuplicateGroup(pics: sortedPics))
            }
        }

        resultGroups.sort { groupA, groupB in
            let earliestA = groupA.pics.first?.dateAdded ?? .distantFuture
            let earliestB = groupB.pics.first?.dateAdded ?? .distantFuture
            return earliestA < earliestB
        }

        duplicateGroups = resultGroups
        scanPhase = .done
        isScanning = false
    }

    func removePics(withIDs deletedIDs: Set<String>) {
        duplicateGroups = duplicateGroups.compactMap { group in
            var updated = group
            updated.pics.removeAll { deletedIDs.contains($0.id) }
            return updated.pics.count >= 2 ? updated : nil
        }
    }

    // MARK: - Union-Find Grouping

    private func findDuplicateGroups(
        hashes: [(String, UInt64)],
        threshold: Int
    ) -> [[(String, UInt64)]] {
        let count = hashes.count
        guard count > 1 else { return [] }

        var parent = Array(0..<count)

        func find(_ index: Int) -> Int {
            var index = index
            while parent[index] != index {
                parent[index] = parent[parent[index]]
                index = parent[index]
            }
            return index
        }

        func union(_ lhs: Int, _ rhs: Int) {
            let rootLHS = find(lhs)
            let rootRHS = find(rhs)
            if rootLHS != rootRHS { parent[rootLHS] = rootRHS }
        }

        for idx in 0..<count {
            for jdx in (idx + 1)..<count {
                let dist = DHash.hammingDistance(hashes[idx].1, hashes[jdx].1)
                if dist <= threshold {
                    union(idx, jdx)
                }
            }
        }

        var groups: [Int: [(String, UInt64)]] = [:]
        for idx in 0..<count {
            let root = find(idx)
            groups[root, default: []].append(hashes[idx])
        }

        return Array(groups.values.filter { $0.count >= 2 })
    }
}
