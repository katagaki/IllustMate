import AppIntents
import WidgetKit

struct AlbumEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Photostand.Entity.Album", table: "Widgets")
    )
    static var defaultQuery = AlbumEntityQuery()

    var id: String
    var libraryID: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct GridAlbumEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Photostand.Entity.Album", table: "Widgets")
    )
    static var defaultQuery = GridAlbumEntityQuery()

    var id: String
    var libraryID: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

enum AlbumEntityResolver {
    static func suggested(forLibraryID libraryID: String) -> [(id: String, name: String)] {
        PhotostandDatabase.fetchAllAlbums(inLibraryWithID: libraryID)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { (id: $0.id, name: $0.name) }
    }

    static func find(id: String, preferringLibraryID libraryID: String) -> (id: String, libraryID: String, name: String)? {
        if let record = PhotostandDatabase.fetchAlbum(withID: id, inLibraryWithID: libraryID) {
            return (record.id, libraryID, record.name)
        }
        for library in PhotostandDatabase.fetchAllLibraries() where library.id != libraryID {
            if let record = PhotostandDatabase.fetchAlbum(withID: id, inLibraryWithID: library.id) {
                return (record.id, library.id, record.name)
            }
        }
        return nil
    }
}

struct AlbumEntityQuery: EntityQuery {
    @IntentParameterDependency<SelectAlbumIntent>(\.$library)
    var albumIntent

    private var libraryID: String {
        albumIntent?.library.id ?? PhotostandDatabase.defaultLibraryID
    }

    func entities(for identifiers: [String]) async throws -> [AlbumEntity] {
        identifiers.compactMap { id in
            AlbumEntityResolver.find(id: id, preferringLibraryID: libraryID)
                .map { AlbumEntity(id: $0.id, libraryID: $0.libraryID, name: $0.name) }
        }
    }

    func suggestedEntities() async throws -> [AlbumEntity] {
        AlbumEntityResolver.suggested(forLibraryID: libraryID)
            .map { AlbumEntity(id: $0.id, libraryID: libraryID, name: $0.name) }
    }
}

struct GridAlbumEntityQuery: EntityQuery {
    @IntentParameterDependency<SelectAlbumForGridIntent>(\.$library)
    var gridIntent

    private var libraryID: String {
        gridIntent?.library.id ?? PhotostandDatabase.defaultLibraryID
    }

    func entities(for identifiers: [String]) async throws -> [GridAlbumEntity] {
        identifiers.compactMap { id in
            AlbumEntityResolver.find(id: id, preferringLibraryID: libraryID)
                .map { GridAlbumEntity(id: $0.id, libraryID: $0.libraryID, name: $0.name) }
        }
    }

    func suggestedEntities() async throws -> [GridAlbumEntity] {
        AlbumEntityResolver.suggested(forLibraryID: libraryID)
            .map { GridAlbumEntity(id: $0.id, libraryID: libraryID, name: $0.name) }
    }
}
