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

    func save() {
        try? modelContext.save()
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

    func album(for id: String) -> Album? {
        let fetchDescriptor = FetchDescriptor<Album>(
            predicate: #Predicate<Album> { $0.id == id }
        )
        return try? modelContext.fetch(fetchDescriptor).first
    }

    func createAlbum(_ album: Album) {
        modelContext.insert(album)
        try? modelContext.save()
    }

    func sortAlbum(_ albums: [Album], sortedBy sortType: SortType) -> [Album] {
        switch sortType {
        case .nameAscending: albums.sorted(by: { $0.name < $1.name })
        case .nameDescending: albums.sorted(by: { $0.name > $1.name })
        case .illustrationCountAscending: albums.sorted(by: { $0.illustrationCount() < $1.illustrationCount() })
        case .illustrationCountDescending: albums.sorted(by: { $0.illustrationCount() > $1.illustrationCount() })
        }
    }

    func addAlbum(withIdentifier albumID: PersistentIdentifier,
                  toAlbumWithIdentifier destinationAlbumID: PersistentIdentifier) {
        if let album = self[albumID, as: Album.self],
            let destinationAlbum = self[destinationAlbumID, as: Album.self] {
            destinationAlbum.addChildAlbum(album)
        }
        try? modelContext.save()
    }

    func removeFromAlbum(_ album: Album) {
        album.parentAlbum = nil
        try? modelContext.save()
    }

    func deleteAlbum(withIdentifier albumID: PersistentIdentifier) {
        if let album = self[albumID, as: Album.self] {
            if let parentAlbum = album.parentAlbum {
                for illustration in album.illustrations() {
                    addIllustration(withIdentifier: illustration.persistentModelID,
                                    toAlbumWithIdentifier: parentAlbum.persistentModelID)
                }
            }
            modelContext.delete(album)
            try? modelContext.save()
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

    func illustration(for id: String) -> Illustration? {
        let fetchDescriptor = FetchDescriptor<Illustration>(
            predicate: #Predicate<Illustration> { $0.id == id }
        )
        return try? modelContext.fetch(fetchDescriptor).first
    }

    func createIllustration(_ illustration: Illustration) {
        modelContext.insert(illustration)
        illustration.generateThumbnail()
        try? modelContext.save()
    }

    func addIllustration(withIdentifier illustrationID: PersistentIdentifier,
                         toAlbumWithIdentifier albumID: PersistentIdentifier) {
        if let illustration = self[illustrationID, as: Illustration.self],
            let album = self[albumID, as: Album.self] {
            illustration.addToAlbum(album)
        }
        try? modelContext.save()
    }

    func addIllustration(_ illustration: Illustration, toAlbumWithIdentifier albumID: PersistentIdentifier) {
        if let album = self[albumID, as: Album.self] {
            album.addChildIllustration(illustration)
        }
        try? modelContext.save()
    }

    func removeFromAlbum(_ illustration: Illustration) {
        illustration.containingAlbum = nil
        try? modelContext.save()
    }

    func deleteIllustration(withIdentifier illustrationID: PersistentIdentifier) {
        @AppStorage(wrappedValue: false, "DebugDeleteWithoutFile") var deleteWithoutFile: Bool
        if let illustration = self[illustrationID, as: Illustration.self] {
            if !deleteWithoutFile {
                illustration.prepareForDeletion()
            }
            if let cachedThumbnail = illustration.cachedThumbnail {
                modelContext.delete(cachedThumbnail)
            }
            modelContext.delete(illustration)
        }
        try? modelContext.save()
    }

    func thumbnails() throws -> [Thumbnail] {
        let fetchDescriptor = FetchDescriptor<Thumbnail>()
        return try modelContext.fetch(fetchDescriptor)
    }

    func deleteAllThumbnails() {
        for thumbnail in ((try? thumbnails()) ?? []) {
            modelContext.delete(thumbnail)
        }
        try? modelContext.save()
    }

    func deleteThumbnail(withIdentifier thumbnailID: PersistentIdentifier) {
        if let thumbnail = self[thumbnailID, as: Thumbnail.self] {
            modelContext.delete(thumbnail)
        }
        try? modelContext.save()
    }

    func deleteAll() {
        try? modelContext.delete(model: Illustration.self, includeSubclasses: true)
        try? modelContext.delete(model: Album.self, includeSubclasses: true)
        try? modelContext.delete(model: Thumbnail.self, includeSubclasses: true)
        do {
            for illustration in try modelContext.fetch(FetchDescriptor<Illustration>()) {
                modelContext.delete(illustration)
            }
            for album in try modelContext.fetch(FetchDescriptor<Album>()) {
                modelContext.delete(album)
            }
            for thumbnail in try modelContext.fetch(FetchDescriptor<Thumbnail>()) {
                modelContext.delete(thumbnail)
            }
        } catch {
            debugPrint(error.localizedDescription)
        }
        try? modelContext.save()
    }
}
