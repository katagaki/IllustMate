import Foundation
@preconcurrency import SQLite

struct EntityPrototype: Codable, Sendable {
    var centroid: [Float]
    var medoidPicID: String
    var memberCount: Int
    var labels: [String]
}

struct AlbumModel: Codable, Sendable {
    var prototypes: [EntityPrototype]
    var memberCount: Int
    var limitedData: Bool
}

actor AlbumModelActor {

    nonisolated(unsafe) private static var _shared = AlbumModelActor(collectionID: PicLibrary.defaultID)
    static var shared: AlbumModelActor { _shared }

    static let currentPrintVersion = FeaturePrintActor.currentPrintVersion

    static func switchLibrary(to collectionID: String) {
        _shared = AlbumModelActor(collectionID: collectionID)
    }

    static func instance(for collectionID: String) -> AlbumModelActor {
        if collectionID == _shared.collectionID {
            return _shared
        }
        return AlbumModelActor(collectionID: collectionID)
    }

    nonisolated let collectionID: String

    let database: Connection

    let modelsTable = Table("album_models")

    let modelAlbumId = Expression<String>("album_id")
    let modelData = Expression<Data>("model_data")
    let modelMemberSignature = Expression<String>("member_signature")
    let modelPrintVersion = Expression<Int>("print_version")

    init(collectionID: String) {
        self.collectionID = collectionID
        let databaseFileName = "AlbumModels.db"
        let fileManager = FileManager.default

        let databaseURL: URL
        if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.IllustMate"
        ) {
            if collectionID == PicLibrary.defaultID {
                databaseURL = appGroupURL.appendingPathComponent(databaseFileName)
            } else {
                let folderURL = appGroupURL.appendingPathComponent(collectionID)
                try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
                databaseURL = folderURL.appendingPathComponent(databaseFileName)
            }
        } else {
            fatalError()
        }

        let database: Connection
        do {
            database = try Connection(databaseURL.path)
        } catch {
            fatalError("Could not open SQLite album model database: \(error)")
        }
        self.database = database
        do {
            try database.run(modelsTable.create(ifNotExists: true) { table in
                table.column(modelAlbumId, primaryKey: true)
                table.column(modelData)
                table.column(modelMemberSignature)
                table.column(modelPrintVersion, defaultValue: 1)
            })
        } catch {
            debugPrint("Album model database setup error: \(error)")
        }
    }

    // MARK: - Read

    func cachedModel(forAlbumWithID albumID: String) -> (model: AlbumModel, signature: String)? {
        let query = modelsTable
            .filter(modelAlbumId == albumID && modelPrintVersion == Self.currentPrintVersion)
        guard let row = try? database.pluck(query),
              let data = try? row.get(modelData),
              let model = try? JSONDecoder().decode(AlbumModel.self, from: data),
              let signature = try? row.get(modelMemberSignature) else { return nil }
        return (model, signature)
    }

    // MARK: - Write

    func storeModel(_ model: AlbumModel, signature: String, forAlbumWithID albumID: String) {
        guard let data = try? JSONEncoder().encode(model) else { return }
        _ = try? database.run(modelsTable.insert(or: .replace,
            modelAlbumId <- albumID,
            modelData <- data,
            modelMemberSignature <- signature,
            modelPrintVersion <- Self.currentPrintVersion
        ))
    }

    // MARK: - Delete

    func deleteModel(forAlbumWithID albumID: String) {
        let query = modelsTable.filter(modelAlbumId == albumID)
        _ = try? database.run(query.delete())
    }

    func deleteModels(forAlbumIDs albumIDs: [String]) {
        guard !albumIDs.isEmpty else { return }
        let query = modelsTable.filter(albumIDs.contains(modelAlbumId))
        _ = try? database.run(query.delete())
    }

    func deleteAllModels() {
        _ = try? database.run(modelsTable.delete())
    }
}
