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
        let imageData = PhotostandDatabase.fetchRandomPicData(inAlbumWithID: album.id)
        return PhotostandEntry(date: .now, albumID: album.id, albumName: album.name, imageData: imageData)
    }

    func timeline(for configuration: SelectAlbumIntent, in context: Context) async -> Timeline<PhotostandEntry> {
        guard let album = configuration.album else {
            let entry = PhotostandEntry(date: .now, albumID: nil, albumName: nil, imageData: nil)
            return Timeline(entries: [entry], policy: .never)
        }

        let picCount = PhotostandDatabase.fetchPicCount(inAlbumWithID: album.id)
        let interval = configuration.refreshInterval

        if picCount == 0 {
            let entry = PhotostandEntry(date: .now, albumID: album.id, albumName: album.name, imageData: nil)
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(interval.seconds)))
        }

        // Generate entries covering the next 24 hours at the selected interval
        var entries: [PhotostandEntry] = []
        entries.reserveCapacity(interval.entryCount)
        let currentDate = Date.now
        for entryIndex in 0..<interval.entryCount {
            let entryDate = currentDate.addingTimeInterval(interval.seconds * Double(entryIndex))
            // Use autoreleasepool so the full-size UIImage from decoding is freed each iteration
            let imageData: Data? = autoreleasepool {
                PhotostandDatabase.fetchRandomPicData(inAlbumWithID: album.id)
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
}
