//
//  OfflineDownloadProgress.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//

import Foundation
import Observation

/// In-memory, device-local progress for albums currently being saved offline,
/// so an album cover can show a download donut. Not persisted or synced.
@MainActor
@Observable
final class OfflineDownloadProgress {

    static let shared = OfflineDownloadProgress()

    private var fractions: [String: Double] = [:]

    func begin(_ albumID: String) { fractions[albumID] = 0.0 }

    func update(_ albumID: String, fraction: Double) { fractions[albumID] = fraction }

    func finish(_ albumID: String) { fractions[albumID] = nil }

    func fraction(for albumID: String) -> Double? { fractions[albumID] }
}
