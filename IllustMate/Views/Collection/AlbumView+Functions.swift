//
//  AlbumView+Functions.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/15.
//

import Foundation
import SwiftData
import SwiftUI

extension AlbumView {

    func deleteAlbum(_ album: Album) {
        isConfirmingDeleteAlbum = true
        albumPendingDeletion = album
    }

    func confirmDeleteAlbum() {
        if let albumPendingDeletion {
            Task {
                await actor.deleteAlbum(withIdentifier: albumPendingDeletion.persistentModelID)
                await refreshData()
            }
        }
    }

    func deleteIllustration(_ illustration: Illustration?) {
        if let illustration {
            isConfirmingDeleteIllustration = true
            illustrationPendingDeletion = illustration
        } else {
            isConfirmingDeleteSelectedIllustrations = true
        }
    }

    func deleteIllustrations() {
        isConfirmingDeleteSelectedIllustrations = true
    }

    func confirmDeleteIllustration() {
        Task { [isSelectingIllustrations, selectedIllustrations] in
            if isSelectingIllustrations {
                for illustration in selectedIllustrations {
                    await actor.deleteIllustration(withIdentifier: illustration.persistentModelID)
                }
            } else {
                if let illustrationPendingDeletion = illustrationPendingDeletion {
                    await actor.deleteIllustration(withIdentifier: illustrationPendingDeletion.persistentModelID)
                }
            }
            self.selectedIllustrations.removeAll()
            refreshIllustrationsAndSet()
        }
    }

    func startOrStopSelectingIllustrations() {
        doWithAnimation {
            if isSelectingIllustrations {
                selectedIllustrations.removeAll()
            }
            isSelectingIllustrations.toggle()
        }
    }

    func moveDropToAlbum(_ drop: Drop, to album: Album) {
        if let transferable = drop.illustration {
            let fetchDescriptor = FetchDescriptor<Illustration>(
                predicate: #Predicate<Illustration> { $0.id == transferable.id }
            )
            if let illustrations = try? modelContext.fetch(fetchDescriptor) {
                moveIllustrationsToAlbum(illustrations, to: album)
            }
        } else if let transferable = drop.album {
            let fetchDescriptor = FetchDescriptor<Album>(
                predicate: #Predicate<Album> { $0.id == transferable.id }
            )
            if let albums = try? modelContext.fetch(fetchDescriptor) {
                moveAlbumsToAlbum(albums, to: album)
            }
        } else if let transferable = drop.importedPhoto {
            importPhotoToAlbum(transferable, to: album)
        }
    }

    func moveIllustrationsToAlbum(_ illustrations: [Illustration], to album: Album) {
        Task(priority: .userInitiated) {
            for illustration in illustrations {
                await actor.addIllustration(withIdentifier: illustration.persistentModelID,
                                            toAlbumWithIdentifier: album.persistentModelID)
            }
            await refreshData()
        }
    }

    func moveAlbumsToAlbum(_ albums: [Album], to album: Album) {
        if !albums.contains(where: { $0.id == album.id }) {
            Task(priority: .userInitiated) {
                for destinationAlbum in albums {
                    await actor.addAlbum(withIdentifier: destinationAlbum.persistentModelID,
                                         toAlbumWithIdentifier: album.persistentModelID)
                }
                await refreshData()
            }
        }
    }

    func importPhotoToAlbum(_ photo: Image, to album: Album) {
        // TODO: Import photo dropped from outside app
    }

    func refreshDataAfterIllustrationMoved() {
        selectedIllustrations.removeAll()
        refreshIllustrationsAndSet()
    }

    func selectOrDeselectIllustration(_ illustration: Illustration) {
        if isSelectingIllustrations {
            if selectedIllustrations.contains(where: { $0.id == illustration.id }) {
                selectedIllustrations.removeAll(where: { $0.id == illustration.id })
            } else {
                selectedIllustrations.append(illustration)
            }
        } else {
            viewerManager.setDisplay(illustration)
        }
    }

    func refreshData() async {
        if slowItDown {
            try? await Task.sleep(nanoseconds: 2000000000)
        }
        let albums = await refreshAlbums()
        let illustrations = await refreshIllustrations()
        await MainActor.run {
            doWithAnimation {
                self.albums = albums
                self.illustrations = illustrations
            }
        }
    }

    func refreshAlbumsAndSet() {
        Task.detached(priority: .userInitiated) {
            let albums = await refreshAlbums()
            await MainActor.run {
                doWithAnimation {
                    self.albums = albums
                }
            }
        }
    }

    func refreshAlbums() async -> [Album] {
        do {
            let albums = try await actor.albums(in: currentAlbum, sortedBy: albumSort)
            return albums
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }

    func refreshIllustrationsAndSet() {
        Task.detached(priority: .userInitiated) {
            let illustrations = await refreshIllustrations()
            await MainActor.run {
                doWithAnimation {
                    self.illustrations = illustrations
                }
            }
        }
    }

    func refreshIllustrations() async -> [Illustration] {
        do {
            let illustrations = try await actor
                .illustrations(in: currentAlbum, order: isIllustrationSortReversed ? .forward : .reverse)
            return illustrations
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }
}
