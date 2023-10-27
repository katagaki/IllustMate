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
        if let transferable = drop.illustration {
            moveIllustrationsToAlbum([transferable.id], to: album)
        } else if let transferable = drop.album {
            moveAlbumsToAlbum([transferable.id], to: album)
        } else if let transferable = drop.importedPhoto {
            importPhotoToAlbum(transferable, to: album)
        }
    }

    func moveIllustrationsToAlbum(_ illustrationIDs: [String], to album: Album) {
        Task(priority: .userInitiated) {
            for illustrationID in illustrationIDs {
                if let illustration = await actor.illustration(for: illustrationID) {
                    await actor.addIllustration(withIdentifier: illustration.persistentModelID,
                                                toAlbumWithIdentifier: album.persistentModelID)
                }
            }
            await refreshData()
        }
    }

    func moveAlbumsToAlbum(_ albumIDs: [String], to album: Album) {
        Task(priority: .userInitiated) {
            for albumID in albumIDs {
                if let destinationAlbum = await actor.album(for: albumID) {
                    await actor.addAlbum(withIdentifier: destinationAlbum.persistentModelID,
                                         toAlbumWithIdentifier: album.persistentModelID)
                }
            }
            await refreshData()
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
        Task.detached(priority: .userInitiated) {
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
        Task.detached(priority: .userInitiated) {
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
