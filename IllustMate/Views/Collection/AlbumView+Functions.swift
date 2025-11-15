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
                await actor.deleteAlbum(withID: albumPendingDeletion.persistentModelID)
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
        // TODO: Use actor to delete multiple illustrations instead of for loop here
        Task { [isSelectingIllustrations, selectedIllustrations] in
            if isSelectingIllustrations {
                for illustration in selectedIllustrations {
                    await actor.deleteIllustration(withID: illustration.persistentModelID)
                }
            } else {
                if let illustrationPendingDeletion = illustrationPendingDeletion {
                    await actor.deleteIllustration(withID: illustrationPendingDeletion.persistentModelID)
                }
            }
            self.selectedIllustrations.removeAll()
            refreshIllustrationsAndSet()
        }
    }

    @MainActor
    func startOrStopSelectingIllustrations() {
        doWithAnimation {
            if isSelectingIllustrations {
                selectedIllustrations.removeAll()
            }
            isSelectingIllustrations.toggle()
        }
    }

    func moveDropToAlbum(_ drop: Drop, to album: Album) {
        Task {
            if let transferable = drop.illustration {
                await moveIllustrationToAlbum(transferable.id, to: album)
            } else if let transferable = drop.album {
                if transferable.id != album.id {
                    await moveAlbumToAlbum(transferable.id, to: album)
                }
            } else if let transferable = drop.importedPhoto {
                await importPhotoToAlbum(transferable, to: album)
            }
            await refreshData()
        }
    }

    func moveIllustrationToAlbum(_ illustrationID: String, to album: Album) async {
        if let illustrationPID = await actor.illustrationID(for: illustrationID) {
            await actor.addIllustration(withID: illustrationPID,
                                        toAlbumWithID: album.persistentModelID)
        }
    }

    func moveAlbumToAlbum(_ albumID: String, to album: Album) async {
        if let destinationAlbumPID = await actor.albumID(for: albumID) {
            await actor.addAlbum(withID: destinationAlbumPID,
                                 toAlbumWithID: album.persistentModelID)
        }
    }

    func importPhotoToAlbum(_ photo: Image, to album: Album) async {
        let uiImage = await photo.render()
        if let data = uiImage?.data() {
            await actor.createIllustration(Illustration.newFilename(), data: data)
        }
    }

    func refreshDataAfterIllustrationMoved() {
        selectedIllustrations.removeAll()
        Task {
            await refreshData()
        }
    }

    func selectOrDeselectIllustration(_ illustration: Illustration) {
        if isSelectingIllustrations {
            if selectedIllustrations.contains(where: { $0.id == illustration.id }) {
                selectedIllustrations.removeAll(where: { $0.id == illustration.id })
            } else {
                selectedIllustrations.append(illustration)
            }
        } else {
            viewer.setDisplay(illustration) {
                navigationManager.push(.illustrationViewer(namespace: namespace), for: .collection)
            }
        }
    }

    func refreshData() async {
        let albums = await fetchAlbums()
        let illustrations = await fetchIllustrations()
        await MainActor.run {
            doWithAnimation {
                self.albums = albums
                self.illustrations = illustrations
            }
        }
    }

    func fetchAlbums() async -> [Album] {
        do {
            let albumIDs = try await actor.albumIDs(in: currentAlbum, sortedBy: albumSort)
            return await MainActor.run {
                albumIDs.compactMap { modelContext[$0, as: Album.self] }
            }
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }

    func refreshAlbumsAndSet() {
        Task.detached(priority: .userInitiated) {
            let albums = await fetchAlbums()
            await MainActor.run {
                doWithAnimation {
                    self.albums = albums
                }
            }
        }
    }

    func fetchIllustrations() async -> [Illustration] {
        do {
            let illustrationIDs = try await actor
                .illustrationIDs(in: currentAlbum, order: isIllustrationSortReversed ? .forward : .reverse)
            return await MainActor.run {
                illustrationIDs.compactMap { modelContext[$0, as: Illustration.self] }
            }
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }

    func refreshIllustrationsAndSet() {
        Task.detached(priority: .userInitiated) {
            let illustrations = await fetchIllustrations()
            await MainActor.run {
                doWithAnimation {
                    self.illustrations = illustrations
                }
            }
        }
    }
}
