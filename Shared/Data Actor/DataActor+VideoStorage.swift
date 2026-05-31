import Foundation

extension DataActor {

    static let videosDirectoryName = "Videos"

    nonisolated func videosDirectoryURL() -> URL {
        databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent(Self.videosDirectoryName, isDirectory: true)
    }

    func ensureVideosDirectoryExists() {
        let url = videosDirectoryURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

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

    nonisolated func videoFileURL(forRelativePath path: String) -> URL {
        databaseURL
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }

    func deleteVideoFile(atRelativePath path: String) {
        let fileURL = videoFileURL(forRelativePath: path)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
