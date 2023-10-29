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
        // TODO: Use actor to delete multiple illustrations instead of for loop here
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
                await moveAlbumToAlbum(transferable.id, to: album)
            } else if let transferable = drop.importedPhoto {
                await importPhotoToAlbum(transferable, to: album)
            }
            await refreshData()
        }
    }

    func moveIllustrationToAlbum(_ illustrationID: String, to album: Album) async {
        if let illustration = await actor.illustration(for: illustrationID) {
            await actor.addIllustration(withIdentifier: illustration.persistentModelID,
                                        toAlbumWithIdentifier: album.persistentModelID)
        }
    }

    func moveAlbumToAlbum(_ albumID: String, to album: Album) async {
        if let destinationAlbum = await actor.album(for: albumID) {
            await actor.addAlbum(withIdentifier: destinationAlbum.persistentModelID,
                                 toAlbumWithIdentifier: album.persistentModelID)
        }
    }

    func importPhotoToAlbum(_ photo: Image, to album: Album) async {
        let uiImage = await photo.render()
        if let data = uiImage?.data() {
            let illustration = Illustration(name: Illustration.newFilename(), data: data)
            await actor.createIllustration(illustration)
            await actor.addIllustration(illustration, toAlbumWithIdentifier: album.persistentModelID)
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
            viewerManager.setDisplay(illustration)
        }
    }

    func refreshData() async {
        let albums = await fetchAlbums()
        let illustrations = await fetchIllustrations()
        await MainActor.run {
            if isFB13295421Fixed {
                doWithAnimation {
                    self.albums = albums
                    self.illustrations = illustrations
                }
            } else {
                self.albums = albums
                self.illustrations = illustrations
            }
        }
    }

    func fetchAlbums() async -> [Album] {
        do {
            let albums = try await actor.albums(in: currentAlbum, sortedBy: albumSort)
            return albums
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }

    func refreshAlbumsAndSet() {
        Task {
            let albums = await fetchAlbums()
            await MainActor.run {
                if isFB13295421Fixed {
                    doWithAnimation {
                        self.albums = albums
                    }
                } else {
                    self.albums = albums
                }
            }
        }
    }

    func fetchIllustrations() async -> [Illustration] {
        do {
            let illustrations = try await actor
                .illustrations(in: currentAlbum, order: isIllustrationSortReversed ? .forward : .reverse)
            return illustrations
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }

    func refreshIllustrationsAndSet() {
        Task {
            let illustrations = await fetchIllustrations()
            await MainActor.run {
                if isFB13295421Fixed {
                    doWithAnimation {
                        self.illustrations = illustrations
                    }
                } else {
                    self.illustrations = illustrations
                }
            }
        }
    }
}
