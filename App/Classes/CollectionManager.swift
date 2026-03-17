//
//  CollectionManager.swift
//  PicMate
//
//  Created by Claude on 2026/03/17.
//

import Foundation
import SwiftUI

@MainActor
class CollectionManager: ObservableObject {

    @Published var currentCollection: Collection = Collection()
    @Published var collections: [Collection] = []

    @AppStorage("CurrentCollectionID",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate"))
    var currentCollectionID: String = Collection.defaultID

    func loadCollections() async {
        let allCollections = await CollectionsActor.shared.allCollections()
        collections = allCollections

        // Restore last selected collection
        if let saved = allCollections.first(where: { $0.id == currentCollectionID }) {
            currentCollection = saved
        } else {
            // Fallback to default
            currentCollection = allCollections.first(where: { $0.isDefault }) ?? Collection()
            currentCollectionID = Collection.defaultID
        }
        switchActors(to: currentCollection.id)
    }

    func switchCollection(to collection: Collection) {
        currentCollection = collection
        currentCollectionID = collection.id
        switchActors(to: collection.id)
    }

    func createCollection(name: String) async -> Collection {
        let collection = await CollectionsActor.shared.createCollection(name: name)
        await loadCollections()
        return collection
    }

    func renameCollection(_ collection: Collection, to newName: String) async {
        await CollectionsActor.shared.renameCollection(withID: collection.id, to: newName)
        await loadCollections()
        if currentCollection.id == collection.id {
            currentCollection.name = newName.trimmingCharacters(in: .whitespaces)
        }
    }

    func deleteCollection(_ collection: Collection) async {
        guard !collection.isDefault else { return }
        await CollectionsActor.shared.deleteCollection(withID: collection.id)
        if currentCollection.id == collection.id {
            let defaultCollection = Collection()
            switchCollection(to: defaultCollection)
        }
        await loadCollections()
    }

    private func switchActors(to collectionID: String) {
        DataActor.switchCollection(to: collectionID)
        HashActor.switchCollection(to: collectionID)
        CoverCacheActor.switchCollection(to: collectionID)
        PColorActor.switchCollection(to: collectionID)
    }

    func displayName(for collection: Collection) -> String {
        if collection.isDefault {
            return String(localized: "Collection.Default", table: "Collections")
        }
        return collection.name
    }
}
