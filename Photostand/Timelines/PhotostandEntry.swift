import os
import WidgetKit

struct PhotostandEntry: TimelineEntry {
    let date: Date
    let albumID: String?
    let albumName: String?
    let imageData: Data?
}

struct PhotostandProvider: AppIntentTimelineProvider {
    static let log = Logger(subsystem: "com.tsubuzaki.IllustMate.Photostand", category: "Timeline")

    func placeholder(in context: Context) -> PhotostandEntry {
        PhotostandEntry(date: .now, albumID: nil, albumName: nil, imageData: nil)
    }

    func snapshot(for configuration: SelectAlbumIntent, in context: Context) async -> PhotostandEntry {
        guard let album = configuration.album else {
            return PhotostandEntry(date: .now, albumID: nil, albumName: nil, imageData: nil)
        }
        let libraryID = configuration.library?.id ?? album.libraryID
        let maxDimension = maxDimension(for: context.family)
        let imageData = PhotostandDatabase.fetchRandomPicData(
            inAlbumWithID: album.id, inLibraryWithID: libraryID, maxDimension: maxDimension
        )
        return PhotostandEntry(date: .now, albumID: album.id, albumName: album.name, imageData: imageData)
    }

    func timeline(for configuration: SelectAlbumIntent, in context: Context) async -> Timeline<PhotostandEntry> {
        guard let album = configuration.album else {
            Self.log.notice("Photostand timeline: no album configured")
            let entry = PhotostandEntry(date: .now, albumID: nil, albumName: nil, imageData: nil)
            return Timeline(entries: [entry], policy: .never)
        }

        let libraryID = configuration.library?.id ?? album.libraryID
        guard let database = PhotostandDatabase.openDatabase(forLibraryID: libraryID) else {
            Self.log.error("Photostand timeline: failed to open database")
            let entry = PhotostandEntry(date: .now, albumID: album.id, albumName: album.name, imageData: nil)
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600)))
        }

        let picCount = PhotostandDatabase.fetchPicCount(inAlbumWithID: album.id, inLibraryWithID: libraryID)
        let interval = configuration.refreshInterval
        Self.log.notice("Photostand timeline: album \(album.id, privacy: .public) pics=\(picCount)")

        if picCount == 0 {
            let entry = PhotostandEntry(date: .now, albumID: album.id, albumName: album.name, imageData: nil)
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(interval.seconds)))
        }

        let maxDim = maxDimension(for: context.family)

        var entries: [PhotostandEntry] = []
        entries.reserveCapacity(interval.entryCount)
        let currentDate = Date.now
        for entryIndex in 0..<interval.entryCount {
            let entryDate = currentDate.addingTimeInterval(interval.seconds * Double(entryIndex))
            // Use autoreleasepool so intermediate buffers are freed each iteration
            let imageData: Data? = autoreleasepool {
                PhotostandDatabase.fetchRandomPicData(
                    using: database, albumID: album.id, libraryID: libraryID, maxDimension: maxDim
                )
            }
            entries.append(PhotostandEntry(
                date: entryDate,
                albumID: album.id,
                albumName: album.name,
                imageData: imageData
            ))
        }

        let withImages = entries.filter { $0.imageData != nil }.count
        Self.log.notice("Photostand timeline: \(entries.count) entries, \(withImages) with images")
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// Widgets render at 2x-3x scale, so target ~2x the point size.
    private func maxDimension(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall:
            return 400
        case .systemMedium, .systemLarge:
            return 600
        @unknown default:
            return 400
        }
    }
}
