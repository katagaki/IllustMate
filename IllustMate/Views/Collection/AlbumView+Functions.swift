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

    func deleteAlbum(_ album: PhotoAlbum) {
        isConfirmingDeleteAlbum = true
        albumPendingDeletion = album
    }

    func confirmDeleteAlbum() {
        if let albumPendingDeletion {
            Task {
                try? await photosActor.deleteAlbum(withID: albumPendingDeletion.id)
                await refreshData()
            }
        }
    }

    func deleteIllustration(_ illustration: PhotoIllustration?) {
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
                let ids = selectedIllustrations.map { $0.id }
                try? await photosActor.deleteIllustrations(withIDs: ids)
            } else {
                if let illustrationPendingDeletion = illustrationPendingDeletion {
                    try? await photosActor.deleteIllustration(withID: illustrationPendingDeletion.id)
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

    func moveDropToAlbum(_ drop: Drop, to album: PhotoAlbum) {
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

    func moveIllustrationToAlbum(_ illustrationID: String, to album: PhotoAlbum) async {
        try? await photosActor.addIllustration(withID: illustrationID, toAlbum: album)
    }

    func moveAlbumToAlbum(_ albumID: String, to album: PhotoAlbum) async {
        // Moving albums between folders is not supported by PhotoKit
        // This would require more complex operations
    }

    func importPhotoToAlbum(_ photo: Image, to album: PhotoAlbum) async {
        let uiImage = await photo.render()
        if let data = uiImage?.data() {
            try? await photosActor.createIllustration("Photo", data: data, inAlbum: album)
        }
    }

    func refreshDataAfterIllustrationMoved() {
        selectedIllustrations.removeAll()
        Task {
            await refreshData()
        }
    }

    func selectOrDeselectIllustration(_ illustration: PhotoIllustration) {
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

    func fetchAlbums() async -> [PhotoAlbum] {
        let albums = await photosActor.albums(in: currentAlbum, sortedBy: albumSort)
        return albums
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

    func fetchIllustrations() async -> [PhotoIllustration] {
        let illustrations = await photosActor
            .illustrations(in: currentAlbum, order: isIllustrationSortReversed ? .forward : .reverse)
        return illustrations
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
