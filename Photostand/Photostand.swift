//
//  Photostand.swift
//  Photostand
//
//  Created by シン・ジャスティン on 2026/03/09.
//

import AppIntents
@preconcurrency import SQLite
import SwiftUI
import WidgetKit

// MARK: - Database Reader

struct PhotostandDatabase {
    static let appGroupID = "group.com.tsubuzaki.IllustMate"

    // Tables
    static let albumsTable = Table("albums")
    static let picsTable = Table("pics")

    // Album columns
    static let albumId = Expression<String>("id")
    static let albumName = Expression<String>("name")

    // Pic columns
    static let picAlbumId = Expression<String?>("containing_album_id")
    static let picData = Expression<Data>("data")

    struct AlbumRecord {
        let id: String
        let name: String
    }

    static func openDatabase() -> Connection? {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("Collection.db") else { return nil }
        return try? Connection(url.path, readonly: true)
    }

    static func fetchAllAlbums() -> [AlbumRecord] {
        guard let database = openDatabase() else { return [] }
        let query = albumsTable.select(albumId, albumName).order(albumName.asc)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.compactMap { row in
            guard let id = try? row.get(albumId),
                  let name = try? row.get(albumName) else { return nil }
            return AlbumRecord(id: id, name: name)
        }
    }

    static func fetchAlbum(withID id: String) -> AlbumRecord? {
        guard let database = openDatabase() else { return nil }
        let query = albumsTable.filter(albumId == id).select(albumId, albumName)
        guard let row = try? database.pluck(query),
              let rowId = try? row.get(albumId),
              let name = try? row.get(albumName) else { return nil }
        return AlbumRecord(id: rowId, name: name)
    }

    static func fetchRandomPicData(inAlbumWithID albumID: String) -> Data? {
        guard let database = openDatabase() else { return nil }
        let query = picsTable
            .filter(picAlbumId == albumID)
            .select(picData)
            .order(Expression<Int>.random())
            .limit(1)
        guard let row = try? database.pluck(query),
              let data = try? row.get(picData),
              let image = UIImage(data: data) else { return nil }
        return image.resizedForWidget()
    }

    static func fetchPicCount(inAlbumWithID albumID: String) -> Int {
        guard let database = openDatabase() else { return 0 }
        let query = picsTable.filter(picAlbumId == albumID)
        return (try? database.scalar(query.count)) ?? 0
    }
}

// MARK: - Image Helpers

extension UIImage {
    func resizedForWidget() -> Data? {
        let maxDimension: CGFloat = 500
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - App Entity for Album Selection

struct AlbumEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Photostand.Entity.Album"
    static var defaultQuery = AlbumEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct AlbumEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AlbumEntity] {
        let allAlbums = PhotostandDatabase.fetchAllAlbums()
        return allAlbums
            .filter { identifiers.contains($0.id) }
            .map { AlbumEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [AlbumEntity] {
        PhotostandDatabase.fetchAllAlbums()
            .map { AlbumEntity(id: $0.id, name: $0.name) }
    }
}

// MARK: - Widget Configuration Intent

struct SelectAlbumIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Photostand.Intent.Title"
    static var description: IntentDescription = "Photostand.Intent.Description"

    @Parameter(title: "Photostand.Intent.Album")
    var album: AlbumEntity?
}

// MARK: - Timeline Entry

struct PhotostandEntry: TimelineEntry {
    let date: Date
    let albumID: String?
    let albumName: String?
    let imageData: Data?
}

// MARK: - Timeline Provider

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

        if picCount == 0 {
            let entry = PhotostandEntry(date: .now, albumID: album.id, albumName: album.name, imageData: nil)
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600)))
        }

        // Generate entries for the next day, each with a random pic
        var entries: [PhotostandEntry] = []
        let currentDate = Date.now
        for hourOffset in 0..<24 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let imageData = PhotostandDatabase.fetchRandomPicData(inAlbumWithID: album.id)
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

// MARK: - Widget View

struct PhotostandEntryView: SwiftUI.View {
    var entry: PhotostandProvider.Entry

    var body: some SwiftUI.View {
        Group {
            if let imageData = entry.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
    }

    var placeholder: some SwiftUI.View {
        ZStack {
            Color(.systemGray5)
            VStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                if entry.albumID == nil {
                    Text("Photostand.Placeholder.SelectAlbum")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Photostand.Placeholder.NoPics")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Widget Definition

struct Photostand: Widget {
    let kind: String = "Photostand"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectAlbumIntent.self,
            provider: PhotostandProvider()
        ) { entry in
            PhotostandEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
                .widgetURL(widgetURL(for: entry))
        }
        .configurationDisplayName("Photostand.DisplayName")
        .description("Photostand.Description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }

    private func widgetURL(for entry: PhotostandEntry) -> URL? {
        guard let albumID = entry.albumID else { return nil }
        return URL(string: "picmate://album/\(albumID)")
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    Photostand()
} timeline: {
    PhotostandEntry(date: .now, albumID: nil, albumName: nil, imageData: nil)
}

#Preview(as: .systemMedium) {
    Photostand()
} timeline: {
    PhotostandEntry(date: .now, albumID: nil, albumName: nil, imageData: nil)
}

#Preview(as: .systemLarge) {
    Photostand()
} timeline: {
    PhotostandEntry(date: .now, albumID: nil, albumName: nil, imageData: nil)
}
