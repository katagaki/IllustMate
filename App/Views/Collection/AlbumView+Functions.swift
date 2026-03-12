//
//  AlbumView+Functions.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/15.
//

import Foundation
import SwiftUI

extension AlbumView {
    func deleteAlbum(_ album: Album) {
        isConfirmingDeleteAlbum = true
        albumPendingDeletion = album
    }

    func confirmDeleteAlbum() {
        if let albumPendingDeletion {
            Task {
                await DataActor.shared.deleteAlbum(withID: albumPendingDeletion.id)
                await refreshData()
            }
        }
    }

    func deletePic(_ pic: Pic?) {
        if let pic {
            isConfirmingDeletePic = true
            picPendingDeletion = pic
        } else {
            isConfirmingDeleteSelectedPics = true
        }
    }

    func deletePics() {
        isConfirmingDeleteSelectedPics = true
    }

    func confirmDeletePic() {
        Task { [isSelectingPics, selectedPics] in
            if isSelectingPics {
                for pic in selectedPics {
                    await DataActor.shared.deletePic(withID: pic.id)
                }
            } else {
                if let picPendingDeletion = picPendingDeletion {
                    await DataActor.shared.deletePic(withID: picPendingDeletion.id)
                }
            }
            self.selectedPics.removeAll()
            refreshPicsAndSet()
        }
    }

    @MainActor
    func startOrStopSelectingPics() {
        doWithAnimation {
            if isSelectingPics {
                selectedPics.removeAll()
            }
            isSelectingPics.toggle()
        }
    }

    func moveDropToAlbum(_ drop: Drop, to album: Album) {
        Task {
            if let transferable = drop.pic {
                await movePicToAlbum(transferable.id, to: album)
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

    func movePicToAlbum(_ picID: String, to album: Album) async {
        await DataActor.shared.addPic(withID: picID, toAlbumWithID: album.id)
    }

    func moveAlbumToAlbum(_ albumID: String, to album: Album) async {
        await DataActor.shared.addAlbum(withID: albumID, toAlbumWithID: album.id)
    }

    func importPhotoToAlbum(_ photo: Image, to album: Album) async {
        let uiImage = photo.render()
        if let data = uiImage?.data() {
            await DataActor.shared.createPic(Pic.newFilename(), data: data,
                                           inAlbumWithID: album.id)
        }
    }

    func refreshDataAfterPicMoved() {
        selectedPics.removeAll()
        Task {
            await refreshData()
        }
    }

    func selectOrDeselectPic(_ pic: Pic) {
        if isSelectingPics {
            if selectedPics.contains(where: { $0.id == pic.id }) {
                selectedPics.removeAll(where: { $0.id == pic.id })
            } else {
                selectedPics.append(pic)
            }
        } else {
            let picCopy = pic
            if UIDevice.current.userInterfaceIdiom == .phone {
                viewer.setDisplay(picCopy, in: pics) { [navigation] in
                    navigation.push(.picViewer(namespace: namespace), for: .collection)
                }
            } else {
                viewer.setDisplay(picCopy, in: pics) { }
            }
        }
    }

    func refreshData() async {
        await withTaskGroup(of: Void.self) { group in
            if let currentAlbum {
                group.addTask {
                    if let album = await DataActor.shared.album(for: currentAlbum.id) {
                        await MainActor.run {
                            self.currentAlbum = album
                        }
                    }
                }
            }
            group.addTask {
                let albums = await self.fetchAlbums()
                await MainActor.run {
                    withAnimation {
                        self.albums = albums
                    }
                }
            }
            group.addTask {
                // Fetch count first for immediate placeholder layout
                let count = await DataActor.shared.picCount(in: self.currentAlbum)
                await MainActor.run {
                    self.picCount = count
                    self.hasFetchedPicCount = true
                }
                // Then fetch all skeletons (lightweight — no blob data)
                let pics = await self.fetchPics()
                await MainActor.run {
                    self.pics = pics
                    self.hasFetchedPics = true
                }
            }
        }
    }

    func fetchAlbums() async -> [Album] {
        do {
            let albums = try await DataActor.shared.albumsWithCounts(in: currentAlbum, sortedBy: albumSort)
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
                withAnimation {
                    self.albums = albums
                }
            }
        }
    }

    func fetchPics() async -> [Pic] {
        do {
            return try await DataActor.shared.picSkeletons(
                in: currentAlbum, order: isPicSortReversed ? .forward : .reverse
            )
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }

    func refreshPicsAndSet() {
        Task.detached(priority: .userInitiated) {
            let count = await DataActor.shared.picCount(in: self.currentAlbum)
            await MainActor.run {
                self.picCount = count
                self.hasFetchedPicCount = true
            }
            let pics = await self.fetchPics()
            await MainActor.run {
                withAnimation(.smooth.speed(2.0)) {
                    self.pics = pics
                }
                self.hasFetchedPics = true
            }
        }
    }

    func searchAlbums(matching searchText: String) async {
        do {
            let results = try await DataActor.shared.searchAlbums(
                matching: searchText, in: currentAlbum, sortedBy: albumSort
            )
            await MainActor.run {
                withAnimation {
                    self.searchResults = results
                }
            }
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
}
