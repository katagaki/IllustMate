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

    typealias ModelID = PersistentIdentifier

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    func save() {
        modelContext.processPendingChanges()
        try? modelContext.save()
    }

    // MARK: Albums

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

    func createAlbum(_ albumName: String) -> Album {
        let newAlbum = Album(name: albumName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(newAlbum)
        save()
        return newAlbum
    }

    func renameAlbum(withID albumID: ModelID, to newName: String) {
        if let album = self[albumID, as: Album.self] {
            album.name = newName.trimmingCharacters(in: .whitespaces)
        }
        save()
    }

    func sortAlbum(_ albums: [Album], sortedBy sortType: SortType) -> [Album] {
        switch sortType {
        case .nameAscending: albums.sorted(by: { $0.name < $1.name })
        case .nameDescending: albums.sorted(by: { $0.name > $1.name })
        case .sizeAscending:
            albums.sorted(by: {
                objectCount(inAlbumWithID: $0.persistentModelID) <
                    objectCount(inAlbumWithID: $1.persistentModelID)
            })
        case .sizeDescending:
            albums.sorted(by: {
                objectCount(inAlbumWithID: $0.persistentModelID) >
                objectCount(inAlbumWithID: $1.persistentModelID)
            })
        }
    }

    func objectCount(inAlbumWithID albumID: ModelID) -> Int {
        return albumCount(inAlbumWithID: albumID) + illustrationCount(inAlbumWithID: albumID)
    }

    func albumCount(inAlbumWithID albumID: ModelID) -> Int {
        let fetchDescriptor = FetchDescriptor<Album>(
            predicate: #Predicate { $0.parentAlbum?.persistentModelID == albumID })
        let albumCount = try? modelContext.fetchCount(fetchDescriptor)
        return albumCount ?? 0
    }

    func illustrationCount(inAlbumWithID albumID: ModelID) -> Int {
        let fetchDescriptor = FetchDescriptor<Illustration>(
            predicate: #Predicate { $0.containingAlbum?.persistentModelID == albumID })
        let illustrationCount = try? modelContext.fetchCount(fetchDescriptor)
        return illustrationCount ?? 0
    }

    func addAlbum(withID albumID: ModelID,
                  toAlbumWithID destinationAlbumID: ModelID) {
        if let album = self[albumID, as: Album.self],
            let destinationAlbum = self[destinationAlbumID, as: Album.self] {
            destinationAlbum.childAlbums?.append(album)
        }
        save()
    }

    func removeParentAlbum(forAlbumWithidentifier albumID: ModelID) {
        if let album = self[albumID, as: Album.self] {
            album.parentAlbum?.childAlbums?.removeAll(where: { $0.id == album.id })
            save()
        }
    }

    func deleteAlbum(withID albumID: ModelID) {
        if let album = self[albumID, as: Album.self] {
            if let parentAlbum = album.parentAlbum {
                for illustration in album.illustrations() {
                    addIllustration(withID: illustration.persistentModelID,
                                    toAlbumWithID: parentAlbum.persistentModelID)
                }
            }
            modelContext.delete(album)
            save()
        }
    }

    // MARK: Illustrations

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

    func createIllustration(_ name: String, data: Data, inAlbumWithID albumID: ModelID? = nil) {
        let illustration = Illustration(name: name, data: data)
        modelContext.insert(illustration)
        illustration.generateThumbnail()
        if let albumID, let album = self[albumID, as: Album.self] {
            album.childIllustrations?.append(illustration)
        }
        save()
    }

    func addIllustrations(withIDs illustrationIDs: [ModelID], toAlbumWithID albumID: ModelID) {
        if let album = self[albumID, as: Album.self] {
            var illustrations: [Illustration] = []
            for illustrationID in illustrationIDs {
                if let illustration = self[illustrationID, as: Illustration.self] {
                    illustrations.append(illustration)
                }
            }
            album.childIllustrations?.append(contentsOf: illustrations)
        }
        save()
    }

    func addIllustration(withID illustrationID: ModelID, toAlbumWithID albumID: ModelID) {
        if let illustration = self[illustrationID, as: Illustration.self],
            let album = self[albumID, as: Album.self] {
            album.childIllustrations?.append(illustration)
        }
        save()
    }

    func removeParentAlbum(forIllustrationWithID illustrationID: ModelID) {
        if let illustration = self[illustrationID, as: Illustration.self] {
            illustration.containingAlbum?.childIllustrations?
                .removeAll(where: { $0.id == illustration.id })
            save()
        }
    }

    func removeParentAlbum(forIllustrationsWithIDs illustrationIDs: [ModelID]) {
        for illustrationID in illustrationIDs {
            if let illustration = self[illustrationID, as: Illustration.self] {
                illustration.containingAlbum?.childIllustrations?
                    .removeAll(where: { $0.id == illustration.id })
            }
        }
        save()
    }

    func setAsAlbumCover(for illustrationID: ModelID) {
        if let illustration = self[illustrationID, as: Illustration.self],
           let containingAlbum = illustration.containingAlbum {
            let image = UIImage(contentsOfFile: illustration.illustrationPath())
            if let data = image?.jpegData(compressionQuality: 1.0) {
                containingAlbum.coverPhoto = Album.makeCover(data)
                save()
            }
        }
    }

    func deleteIllustration(withID illustrationID: ModelID) {
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
        save()
    }

    func thumbnails() throws -> [Thumbnail] {
        let fetchDescriptor = FetchDescriptor<Thumbnail>()
        return try modelContext.fetch(fetchDescriptor)
    }

    func deleteAllThumbnails() {
        for thumbnail in ((try? thumbnails()) ?? []) {
            modelContext.delete(thumbnail)
        }
        save()
    }

    func deleteThumbnail(withID thumbnailID: ModelID) {
        if let thumbnail = self[thumbnailID, as: Thumbnail.self] {
            modelContext.delete(thumbnail)
        }
        save()
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
        save()
    }
}
