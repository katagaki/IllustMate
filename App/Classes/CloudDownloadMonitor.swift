import Foundation

@MainActor
final class CloudDownloadMonitor {

    private var query: NSMetadataQuery?
    private var pollTask: Task<Void, Never>?
    private var onProgress: ((Double) -> Void)?

    func start(fileName: String, onProgress: @escaping (Double) -> Void) {
        stop()
        self.onProgress = onProgress
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, fileName)
        query.valueListAttributes = [NSMetadataUbiquitousItemPercentDownloadedKey]
        self.query = query
        query.start()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                if let fraction = self?.currentFraction() { self?.onProgress?(fraction) }
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        query?.stop()
        query = nil
        onProgress = nil
    }

    private func currentFraction() -> Double? {
        guard let query else { return nil }
        query.disableUpdates()
        defer { query.enableUpdates() }
        guard let item = query.results.first as? NSMetadataItem,
              let percent = item.value(
                forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey
              ) as? Double else { return nil }
        return min(max(percent / 100.0, 0.0), 1.0)
    }
}
