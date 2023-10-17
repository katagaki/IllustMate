//
//  DataActor.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/17.
//

import Foundation
import SwiftData

actor DataActor: ModelActor {

    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    func albums() throws -> [Album] {
        var fetchDescriptor = FetchDescriptor<Album>(
            sortBy: [SortDescriptor(\.name, order: .forward)])
        fetchDescriptor.propertiesToFetch = [\.name, \.coverPhoto]
        fetchDescriptor.relationshipKeyPathsForPrefetching = [\.childIllustrations]
        return try modelContext.fetch(fetchDescriptor)
    }

    func albums(in album: Album?) throws -> [Album] {
        let albumID = album?.id
        var fetchDescriptor = FetchDescriptor<Album>(
            predicate: #Predicate { $0.parentAlbum?.id == albumID },
            sortBy: [SortDescriptor(\.name, order: .forward)])
        fetchDescriptor.propertiesToFetch = [\.name, \.coverPhoto]
        fetchDescriptor.relationshipKeyPathsForPrefetching = [\.childIllustrations]
        return try modelContext.fetch(fetchDescriptor)
    }

    func addAlbum(withIdentifier albumID: PersistentIdentifier,
                  toAlbumWithIdentifier destinationAlbumID: PersistentIdentifier) {
        if let album = self[albumID, as: Album.self],
            let destinationAlbum = self[destinationAlbumID, as: Album.self] {
            destinationAlbum.addChildAlbum(album)
        }
    }

    func deleteAlbum(withIdentifier albumID: PersistentIdentifier) {
        if let album = self[albumID, as: Album.self] {
            modelContext.delete(album)
        }
    }

    func illustrations() throws -> [Illustration] {
        var fetchDescriptor = FetchDescriptor<Illustration>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        fetchDescriptor.propertiesToFetch = [\.name, \.dateAdded]
        fetchDescriptor.relationshipKeyPathsForPrefetching = [\.cachedThumbnail]
        return try modelContext.fetch(fetchDescriptor)
    }

    func illustrations(in album: Album?, order: SortOrder) throws -> [Illustration] {
        let albumID = album?.id
        var fetchDescriptor = FetchDescriptor<Illustration>(
            predicate: #Predicate { $0.containingAlbum?.id == albumID },
            sortBy: [SortDescriptor(\.dateAdded, order: order)])
        fetchDescriptor.propertiesToFetch = [\.name, \.dateAdded]
        fetchDescriptor.relationshipKeyPathsForPrefetching = [\.cachedThumbnail]
        return try modelContext.fetch(fetchDescriptor)
    }

    func addIllustration(withIdentifier illustrationID: PersistentIdentifier,
                         toAlbumWithIdentifier albumID: PersistentIdentifier) {
        if let illustration = self[illustrationID, as: Illustration.self],
            let album = self[albumID, as: Album.self] {
            illustration.addToAlbum(album)
        }
    }

    func removeFromAlbum(_ illustration: Illustration) {
        illustration.containingAlbum = nil
    }

    func deleteIllustration(withIdentifier illustrationID: PersistentIdentifier) {
        if let illustration = self[illustrationID, as: Illustration.self] {
            illustration.prepareForDeletion()
            modelContext.delete(illustration)
        }
    }
}
