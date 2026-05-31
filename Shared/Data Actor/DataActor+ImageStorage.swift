import Foundation
@preconcurrency import SQLite

extension DataActor {

    static let imagesDirectoryName = "Images"

    nonisolated func imagesDirectoryURL() -> URL {
        databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent(Self.imagesDirectoryName, isDirectory: true)
    }

    func ensureImagesDirectoryExists() {
        let url = imagesDirectoryURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

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

    nonisolated func imageFileURL(forRelativePath path: String) -> URL {
        databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    func deleteImageFile(atRelativePath path: String) {
        let fileURL = imageFileURL(forRelativePath: path)
        try? FileManager.default.removeItem(at: fileURL)
    }

    nonisolated func isImagePath(_ path: String) -> Bool {
        path.hasPrefix("\(Self.imagesDirectoryName)/")
    }
}
