//
//  DataActor+ImageStorage.swift
//  PicMate
//
//  Created by Claude on 2026/05/28.
//

import Foundation
@preconcurrency import SQLite

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

    /// Local file URL of an image pic's original, or nil if it isn't present
    /// locally (e.g. a synced pic whose original lives only in iCloud Drive).
    func localOriginalURL(forPicWithID id: String) -> URL? {
        let query = picsTable.filter(picId == id).select(picFilePath, picMediaType)
        guard let row = try? database.pluck(query),
              (try? row.get(picMediaType)) == MediaType.pic.rawValue,
              let path = try? row.get(picFilePath) else { return nil }
        let url = imageFileURL(forRelativePath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Writes an original fetched from iCloud Drive into the local Images cache
    /// and points the pic at it. Does not mark the pic dirty (sync-driven).
    func importDownloadedOriginal(picID: String, data: Data) {
        guard let relativePath = saveImageFile(data, id: picID) else { return }
        _ = try? database.run(picsTable.filter(picId == picID)
            .update(picFilePath <- relativePath, picData <- nil, syncOriginalSynced <- true))
    }
}
