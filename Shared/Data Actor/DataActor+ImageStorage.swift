//
//  DataActor+ImageStorage.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//

import Foundation

extension DataActor {

    static let imagesDirectoryName = "Images"

    /// Returns the URL of the Images directory within the app group container.
    nonisolated func imagesDirectoryURL() -> URL {
        databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent(Self.imagesDirectoryName, isDirectory: true)
    }

    /// Ensures the Images directory exists.
    func ensureImagesDirectoryExists() {
        let url = imagesDirectoryURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Writes image data to disk and returns the relative path (e.g. "Images/<id>").
    /// Image bytes are stored verbatim; the extension is irrelevant since the
    /// data is always read back raw and decoded via `UIImage(data:)`.
    func saveImageFile(_ data: Data, id: String) -> String? {
        ensureImagesDirectoryExists()
        let relativePath = "\(Self.imagesDirectoryName)/\(id)"
        let fileURL = imagesDirectoryURL().appendingPathComponent(id)
        do {
            try data.write(to: fileURL)
            return relativePath
        } catch {
            debugPrint("Failed to save image file: \(error)")
            return nil
        }
    }

    /// Resolves a relative image path to a full URL.
    nonisolated func imageFileURL(forRelativePath path: String) -> URL {
        databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    /// Deletes an image file from disk.
    func deleteImageFile(atRelativePath path: String) {
        let fileURL = imageFileURL(forRelativePath: path)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// True if the relative path points into the Images directory.
    nonisolated func isImagePath(_ path: String) -> Bool {
        path.hasPrefix("\(Self.imagesDirectoryName)/")
    }
}
