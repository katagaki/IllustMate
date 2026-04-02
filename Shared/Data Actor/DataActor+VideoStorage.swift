//
//  DataActor+VideoStorage.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/04/02.
//

import Foundation

extension DataActor {

    static let videosDirectoryName = "Videos"

    /// Returns the URL of the Videos directory within the app group container.
    nonisolated func videosDirectoryURL() -> URL {
        databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent(Self.videosDirectoryName, isDirectory: true)
    }

    /// Ensures the Videos directory exists. Called during init or first video save.
    func ensureVideosDirectoryExists() {
        let url = videosDirectoryURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Saves video data to disk and returns the relative path (e.g. "Videos/<id>.mp4").
    func saveVideoFile(_ data: Data, id: String, fileExtension: String) -> String? {
        ensureVideosDirectoryExists()
        let filename = "\(id).\(fileExtension)"
        let relativePath = "\(Self.videosDirectoryName)/\(filename)"
        let fileURL = videosDirectoryURL().appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return relativePath
        } catch {
            debugPrint("Failed to save video file: \(error)")
            return nil
        }
    }

    /// Resolves a relative file path to a full URL.
    nonisolated func videoFileURL(forRelativePath path: String) -> URL {
        databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    /// Deletes a video file from disk.
    func deleteVideoFile(atRelativePath path: String) {
        let fileURL = videoFileURL(forRelativePath: path)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
