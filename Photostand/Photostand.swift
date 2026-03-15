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
    static let picId = Expression<String>("id")
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
        // Step 1: Pick a random pic ID without loading blob data
        let idQuery = picsTable
            .filter(picAlbumId == albumID)
            .select(picId)
            .order(Expression<Int>.random())
            .limit(1)
        guard let idRow = try? database.pluck(idQuery),
              let randomId = try? idRow.get(picId) else { return nil }
        // Step 2: Fetch and resize in autoreleasepool so the full-size UIImage is freed
        return autoreleasepool {
            let dataQuery = picsTable
                .filter(picId == randomId)
                .select(picData)
            guard let row = try? database.pluck(dataQuery),
                  let data = try? row.get(picData),
                  let image = UIImage(data: data) else { return nil }
            return image.resizedForWidget()
        }
    }

    static func fetchRandomPicDataMultiple(inAlbumWithID albumID: String, count: Int,
                                              maxDimension: CGFloat = 800) -> [Data] {
        guard let database = openDatabase() else { return [] }
        let idQuery = picsTable
            .filter(picAlbumId == albumID)
            .select(picId)
            .order(Expression<Int>.random())
            .limit(count)
        guard let rows = try? database.prepare(idQuery) else { return [] }
        let ids = rows.compactMap { try? $0.get(picId) }
        return ids.compactMap { id in
            // Autoreleasepool ensures each full-size UIImage is freed before loading the next
            autoreleasepool {
                let dataQuery = picsTable
                    .filter(picId == id)
                    .select(picData)
                guard let row = try? database.pluck(dataQuery),
                      let data = try? row.get(picData),
                      let image = UIImage(data: data) else { return nil }
                return image.resizedForWidget(maxDimension: maxDimension)
            }
        }
    }

    static func fetchPicCount(inAlbumWithID albumID: String) -> Int {
        guard let database = openDatabase() else { return 0 }
        let query = picsTable.filter(picAlbumId == albumID)
        return (try? database.scalar(query.count)) ?? 0
    }
}

// MARK: - Image Helpers

extension UIImage {
    func resizedForWidget(maxDimension: CGFloat = 800) -> Data? {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        guard let resized = preparingThumbnail(of: targetSize) else { return nil }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - App Entity for Album Selection

struct AlbumEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Photostand.Entity.Album", table: "Widgets"))
    static var defaultQuery = AlbumEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct AlbumEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AlbumEntity] {
        PhotostandDatabase.fetchAllAlbums()
            .filter { identifiers.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { AlbumEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [AlbumEntity] {
        PhotostandDatabase.fetchAllAlbums()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { AlbumEntity(id: $0.id, name: $0.name) }
    }
}

// MARK: - Refresh Interval Entity

enum RefreshInterval: String, CaseIterable, AppEnum {
    case threeHours = "3h"
    case sixHours = "6h"
    case twelveHours = "12h"
    case twentyFourHours = "24h"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("Photostand.Entity.RefreshInterval", table: "Widgets"))
    static var caseDisplayRepresentations: [RefreshInterval: DisplayRepresentation] = [
        .threeHours: DisplayRepresentation(title: LocalizedStringResource("Photostand.RefreshInterval.3Hours", table: "Widgets")),
        .sixHours: DisplayRepresentation(title: LocalizedStringResource("Photostand.RefreshInterval.6Hours", table: "Widgets")),
        .twelveHours: DisplayRepresentation(title: LocalizedStringResource("Photostand.RefreshInterval.12Hours", table: "Widgets")),
        .twentyFourHours: DisplayRepresentation(title: LocalizedStringResource("Photostand.RefreshInterval.24Hours", table: "Widgets"))
    ]

    var seconds: TimeInterval {
        switch self {
        case .threeHours: return 10800
        case .sixHours: return 21600
        case .twelveHours: return 43200
        case .twentyFourHours: return 86400
        }
    }

    var entryCount: Int {
        Int(86400 / seconds)
    }
}

// MARK: - Widget Configuration Intent

struct SelectAlbumIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("Photostand.Intent.Title", table: "Widgets")
    static var description = IntentDescription(LocalizedStringResource("Photostand.Intent.Description", table: "Widgets"))

    @Parameter(title: LocalizedStringResource("Photostand.Intent.Album", table: "Widgets"))
    var album: AlbumEntity?

    @Parameter(title: LocalizedStringResource("Photostand.Intent.RefreshInterval", table: "Widgets"), default: .threeHours)
    var refreshInterval: RefreshInterval
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

// MARK: - Widget View

struct PhotostandEntryView: SwiftUI.View {
    var entry: PhotostandProvider.Entry

    var body: some SwiftUI.View {
        Group {
            if let imageData = entry.imageData,
               let uiImage = UIImage(data: imageData) {
                GeometryReader { geometry in
                    Image(uiImage: uiImage)
                        .resizable()
                        .widgetAccentedRenderingMode(.fullColor)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                        .clipped()
                }
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
                    Text("Photostand.Placeholder.SelectAlbum", tableName: "Widgets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Photostand.Placeholder.NoPics", tableName: "Widgets")
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
        .configurationDisplayName(Text("Photostand.DisplayName", tableName: "Widgets"))
        .description(Text("Photostand.Description", tableName: "Widgets"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }

    private func widgetURL(for entry: PhotostandEntry) -> URL? {
        guard let albumID = entry.albumID else { return nil }
        return URL(string: "picmate://album/\(albumID)")
    }
}

// MARK: - Photo Grid Widget Configuration Intent

struct SelectAlbumForGridIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("PhotoGrid.Intent.Title", table: "Widgets")
    static var description = IntentDescription(LocalizedStringResource("PhotoGrid.Intent.Description", table: "Widgets"))

    @Parameter(title: LocalizedStringResource("PhotoGrid.Intent.Album", table: "Widgets"))
    var album: AlbumEntity?
}

// MARK: - Photo Grid Timeline Entry

struct PhotoGridEntry: TimelineEntry {
    let date: Date
    let albumID: String?
    let albumName: String?
    let images: [Data]
    let columns: Int
    let rows: Int
}

// MARK: - Photo Grid Timeline Provider

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
        let images = PhotostandDatabase.fetchRandomPicDataMultiple(
            inAlbumWithID: album.id, count: count, maxDimension: 400
        )
        return PhotoGridEntry(date: .now, albumID: album.id, albumName: album.name, images: images, columns: columns, rows: rows)
    }

    func timeline(for configuration: SelectAlbumForGridIntent, in context: Context) async -> Timeline<PhotoGridEntry> {
        let (columns, rows) = gridSize(for: context.family)
        guard let album = configuration.album else {
            let entry = PhotoGridEntry(date: .now, albumID: nil, albumName: nil, images: [], columns: columns, rows: rows)
            return Timeline(entries: [entry], policy: .never)
        }

        let count = columns * rows
        let picCount = PhotostandDatabase.fetchPicCount(inAlbumWithID: album.id)

        if picCount == 0 {
            let entry = PhotoGridEntry(date: .now, albumID: album.id, albumName: album.name, images: [], columns: columns, rows: rows)
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(86400)))
        }

        // Single entry refreshed every 24 hours to stay within memory limits
        let images: [Data] = autoreleasepool {
            PhotostandDatabase.fetchRandomPicDataMultiple(
                inAlbumWithID: album.id, count: count, maxDimension: 400
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
}

// MARK: - Photo Grid Widget View

struct PhotoGridEntryView: SwiftUI.View {
    var entry: PhotoGridProvider.Entry

    var body: some SwiftUI.View {
        Group {
            if entry.images.isEmpty {
                gridPlaceholder
            } else {
                GeometryReader { geometry in
                    let cellWidth = geometry.size.width / CGFloat(entry.columns)
                    let cellHeight = geometry.size.height / CGFloat(entry.rows)

                    VStack(spacing: 0) {
                        ForEach(0..<entry.rows, id: \.self) { row in
                            HStack(spacing: 0) {
                                ForEach(0..<entry.columns, id: \.self) { col in
                                    let index = row * entry.columns + col
                                    if index < entry.images.count,
                                       let uiImage = UIImage(data: entry.images[index]) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .widgetAccentedRenderingMode(.fullColor)
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: cellWidth, height: cellHeight, alignment: .top)
                                            .clipped()
                                    } else {
                                        Color(.systemGray5)
                                            .frame(width: cellWidth, height: cellHeight)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    var gridPlaceholder: some SwiftUI.View {
        ZStack {
            Color(.systemGray5)
            VStack(spacing: 4) {
                Image(systemName: "square.grid.2x2")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                if entry.albumID == nil {
                    Text("PhotoGrid.Placeholder.SelectAlbum", tableName: "Widgets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("PhotoGrid.Placeholder.NoPics", tableName: "Widgets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Photo Grid Widget Definition

struct PhotoGrid: Widget {
    let kind: String = "PhotoGrid"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectAlbumForGridIntent.self,
            provider: PhotoGridProvider()
        ) { entry in
            PhotoGridEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
                .widgetURL(widgetURL(for: entry))
        }
        .configurationDisplayName(Text("PhotoGrid.DisplayName", tableName: "Widgets"))
        .description(Text("PhotoGrid.Description", tableName: "Widgets"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }

    private func widgetURL(for entry: PhotoGridEntry) -> URL? {
        guard let albumID = entry.albumID else { return nil }
        return URL(string: "picmate://album/\(albumID)")
    }
}
