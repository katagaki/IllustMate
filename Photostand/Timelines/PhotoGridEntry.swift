//
//  PhotoGrid.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import WidgetKit

struct PhotoGridEntry: TimelineEntry {
    let date: Date
    let albumID: String?
    let albumName: String?
    let images: [Data]
    let columns: Int
    let rows: Int
}

struct PhotoGridProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PhotoGridEntry {
        let (columns, rows) = gridSize(for: context.family)
        return PhotoGridEntry(date: .now, albumID: nil, albumName: nil, images: [], columns: columns, rows: rows)
    }

    func snapshot(for configuration: SelectAlbumForGridIntent, in context: Context) async -> PhotoGridEntry {
        let (columns, rows) = gridSize(for: context.family)
        guard let album = configuration.album else {
            return PhotoGridEntry(date: .now, albumID: nil, albumName: nil, images: [], columns: columns, rows: rows)
        }
        let count = columns * rows
        let maxDim = gridMaxDimension(for: context.family)
        let images = PhotostandDatabase.fetchRandomPicDataMultiple(
            inAlbumWithID: album.id, count: count, maxDimension: maxDim
        )
        return PhotoGridEntry(
            date: .now,
            albumID: album.id,
            albumName: album.name,
            images: images,
            columns: columns,
            rows: rows
        )
    }

    func timeline(for configuration: SelectAlbumForGridIntent, in context: Context) async -> Timeline<PhotoGridEntry> {
        let (columns, rows) = gridSize(for: context.family)
        guard let album = configuration.album else {
            let entry = PhotoGridEntry(
                date: .now,
                albumID: nil,
                albumName: nil,
                images: [],
                columns: columns,
                rows: rows
            )
            return Timeline(entries: [entry], policy: .never)
        }

        let count = columns * rows
        let picCount = PhotostandDatabase.fetchPicCount(inAlbumWithID: album.id)

        if picCount == 0 {
            let entry = PhotoGridEntry(
                date: .now,
                albumID: album.id,
                albumName: album.name,
                images: [],
                columns: columns,
                rows: rows
            )
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(86400)))
        }

        let maxDim = gridMaxDimension(for: context.family)

        // Single entry refreshed every 24 hours to stay within memory limits
        let images: [Data] = autoreleasepool {
            PhotostandDatabase.fetchRandomPicDataMultiple(
                inAlbumWithID: album.id, count: count, maxDimension: maxDim
            )
        }
        let entry = PhotoGridEntry(
            date: .now,
            albumID: album.id,
            albumName: album.name,
            images: images,
            columns: columns,
            rows: rows
        )

        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(86400)))
    }

    private func gridSize(for family: WidgetFamily) -> (columns: Int, rows: Int) {
        switch family {
        case .systemSmall:
            return (2, 2)
        case .systemMedium:
            return (4, 2)
        case .systemLarge:
            return (3, 3)
        @unknown default:
            return (2, 2)
        }
    }

    /// Grid cells are much smaller than full widgets, so use smaller dimensions.
    private func gridMaxDimension(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall:
            return 200
        case .systemMedium:
            return 200
        case .systemLarge:
            return 250
        @unknown default:
            return 200
        }
    }
}
