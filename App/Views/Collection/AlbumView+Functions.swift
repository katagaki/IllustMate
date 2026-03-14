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
                    await PColorActor.shared.deleteColor(forPicWithID: pic.id)
                }
            } else {
                if let picPendingDeletion = picPendingDeletion {
                    await DataActor.shared.deletePic(withID: picPendingDeletion.id)
                    await PColorActor.shared.deleteColor(forPicWithID: picPendingDeletion.id)
                }
            }
            self.selectedPics.removeAll()
            refreshPicsAndSet()
        }
    }

    func selectOrDeselectAllPics() {
        if pics.count == selectedPics.count {
            selectedPics.removeAll()
        } else {
            selectedPics.removeAll()
            selectedPics.append(contentsOf: pics)
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
            switch picSortType {
            case .dateAddedAscending:
                return try await DataActor.shared.picSkeletons(
                    in: currentAlbum, order: .forward
                )
            case .dateAddedDescending:
                return try await DataActor.shared.picSkeletons(
                    in: currentAlbum, order: .reverse
                )
            case .prominentColor:
                let pics = try await DataActor.shared.pics(
                    in: currentAlbum, order: .reverse
                )
                return await sortPicsByProminentColor(pics)
            }
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }

    func sortPicsByProminentColor(_ pics: [Pic]) async -> [Pic] {
        // Load only colors for the pics in this list
        let picIDs = pics.map(\.id)
        let cachedColors = await PColorActor.shared.cachedColors(forPicIDs: picIDs)

        // Find pics that need color calculation
        var colorsMap = cachedColors
        let uncachedPics = pics.filter { colorsMap[$0.id] == nil && $0.thumbnailData != nil }

        // Compute colors concurrently
        if !uncachedPics.isEmpty {
            let newColors: [(picID: String, r: Int, g: Int, b: Int)] = await withTaskGroup(
                of: (String, (r: Int, g: Int, b: Int)?).self,
                returning: [(picID: String, r: Int, g: Int, b: Int)].self
            ) { group in
                for pic in uncachedPics {
                    group.addTask {
                        guard let thumbnailData = pic.thumbnailData else { return (pic.id, nil) }
                        let color = ProminentColor.calculate(from: thumbnailData)
                        return (pic.id, color)
                    }
                }
                var results: [(picID: String, r: Int, g: Int, b: Int)] = []
                for await (picID, color) in group {
                    if let color {
                        results.append((picID: picID, r: color.r, g: color.g, b: color.b))
                    }
                }
                return results
            }
            for entry in newColors {
                colorsMap[entry.picID] = (r: entry.r, g: entry.g, b: entry.b)
            }
            await PColorActor.shared.storeColors(newColors)
        }

        // Sort by R, then G, then B
        let defaultColor = (r: 128, g: 128, b: 128)
        return pics.sorted { lhs, rhs in
            let colorA = colorsMap[lhs.id] ?? defaultColor
            let colorB = colorsMap[rhs.id] ?? defaultColor
            if colorA.r != colorB.r { return colorA.r < colorB.r }
            if colorA.g != colorB.g { return colorA.g < colorB.g }
            return colorA.b < colorB.b
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
