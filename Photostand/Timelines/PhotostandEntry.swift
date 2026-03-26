//
//  Photostand.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import WidgetKit

struct PhotostandEntry: TimelineEntry {
    let date: Date
    let albumID: String?
    let albumName: String?
    let imageData: Data?
}

struct PhotostandProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PhotostandEntry {
        PhotostandEntry(date: .now, albumID: nil, albumName: nil, imageData: nil)
    }

    func snapshot(for configuration: SelectAlbumIntent, in context: Context) async -> PhotostandEntry {
        guard let album = configuration.album else {
            return PhotostandEntry(date: .now, albumID: nil, albumName: nil, imageData: nil)
        }
        let maxDimension = maxDimension(for: context.family)
        let imageData = PhotostandDatabase.fetchRandomPicData(
            inAlbumWithID: album.id, maxDimension: maxDimension
        )
        return PhotostandEntry(date: .now, albumID: album.id, albumName: album.name, imageData: imageData)
    }

    func timeline(for configuration: SelectAlbumIntent, in context: Context) async -> Timeline<PhotostandEntry> {
        guard let album = configuration.album else {
            let entry = PhotostandEntry(date: .now, albumID: nil, albumName: nil, imageData: nil)
            return Timeline(entries: [entry], policy: .never)
        }

        guard let database = PhotostandDatabase.openDatabase() else {
            let entry = PhotostandEntry(date: .now, albumID: album.id, albumName: album.name, imageData: nil)
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600)))
        }

        let picCount = PhotostandDatabase.fetchPicCount(inAlbumWithID: album.id)
        let interval = configuration.refreshInterval

        if picCount == 0 {
            let entry = PhotostandEntry(date: .now, albumID: album.id, albumName: album.name, imageData: nil)
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(interval.seconds)))
        }

        let maxDim = maxDimension(for: context.family)

        // Generate entries covering the next 24 hours at the selected interval
        var entries: [PhotostandEntry] = []
        entries.reserveCapacity(interval.entryCount)
        let currentDate = Date.now
        for entryIndex in 0..<interval.entryCount {
            let entryDate = currentDate.addingTimeInterval(interval.seconds * Double(entryIndex))
            // Use autoreleasepool so intermediate buffers are freed each iteration
            let imageData: Data? = autoreleasepool {
                PhotostandDatabase.fetchRandomPicData(
                    using: database, albumID: album.id, maxDimension: maxDim
                )
            }
            entries.append(PhotostandEntry(
                date: entryDate,
                albumID: album.id,
                albumName: album.name,
                imageData: imageData
            ))
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

    /// Returns the appropriate max image dimension for a widget family.
    /// Widgets render at 2x-3x scale, so we target ~2x the point size.
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
