//
//  DataActor.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/17.
//

import Foundation
import SwiftData
import SwiftUI

actor DataActor: ModelActor {

    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    func albums(sortedBy sortType: SortType) throws -> [Album] {
        var fetchDescriptor = FetchDescriptor<Album>()
        fetchDescriptor.propertiesToFetch = [\.name, \.coverPhoto]
        fetchDescriptor.relationshipKeyPathsForPrefetching = [\.childIllustrations]
        let albums = try modelContext.fetch(fetchDescriptor)
        return sortAlbum(albums, sortedBy: sortType)
    }

    func albums(in album: Album?, sortedBy sortType: SortType) throws -> [Album] {
        let albumID = album?.id
        var fetchDescriptor = FetchDescriptor<Album>(
            predicate: #Predicate { $0.parentAlbum?.id == albumID })
        fetchDescriptor.propertiesToFetch = [\.name, \.coverPhoto]
        fetchDescriptor.relationshipKeyPathsForPrefetching = [\.childIllustrations]
        let albums = try modelContext.fetch(fetchDescriptor)
        return sortAlbum(albums, sortedBy: sortType)
    }

    func sortAlbum(_ albums: [Album], sortedBy sortType: SortType) -> [Album] {
        switch sortType {
        case .nameAscending: albums.sorted(by: { $0.name < $1.name })
        case .nameDescending: albums.sorted(by: { $0.name > $1.name })
        case .illustrationCountAscending: albums.sorted(by: { $0.illustrations().count < $1.illustrations().count })
        case .illustrationCountDescending: albums.sorted(by: { $0.illustrations().count > $1.illustrations().count })
        }
    }

    func addAlbum(withIdentifier albumID: PersistentIdentifier,
                  toAlbumWithIdentifier destinationAlbumID: PersistentIdentifier) {
        if let album = self[albumID, as: Album.self],
            let destinationAlbum = self[destinationAlbumID, as: Album.self] {
            destinationAlbum.addChildAlbum(album)
        }
    }

    func removeFromAlbum(_ album: Album) {
        album.parentAlbum = nil
    }

    func deleteAlbum(withIdentifier albumID: PersistentIdentifier) {
        if let album = self[albumID, as: Album.self] {
            modelContext.delete(album)
        }
    }

    func createIllustration(_ illustration: Illustration) {
        modelContext.insert(illustration)
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

    func addIllustration(_ illustration: Illustration, toAlbumWithIdentifier albumID: PersistentIdentifier) {
        if let album = self[albumID, as: Album.self] {
            album.addChildIllustration(illustration)
        }
    }

    func removeFromAlbum(_ illustration: Illustration) {
        illustration.containingAlbum = nil
    }

    func deleteIllustration(withIdentifier illustrationID: PersistentIdentifier) {
        @AppStorage(wrappedValue: false, "DebugDeleteWithoutFile") var deleteWithoutFile: Bool
        if let illustration = self[illustrationID, as: Illustration.self] {
            if !deleteWithoutFile {
                illustration.prepareForDeletion()
            }
            modelContext.delete(illustration)
        }
    }
}
