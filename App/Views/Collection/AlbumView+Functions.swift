//
//  AlbumView+Functions.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/15.
//

import CoreImage
import CoreImage.CIFilterBuiltins
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
            var deletedIDs = Set<String>()
            if isSelectingPics {
                let picIDs = selectedPics.map(\.id)
                deletedIDs = Set(picIDs)
                await DataActor.shared.deletePics(withIDs: picIDs)
                await PColorActor.shared.deleteColors(forPicIDs: picIDs)
            } else {
                if let picPendingDeletion = picPendingDeletion {
                    await DataActor.shared.deletePic(withID: picPendingDeletion.id)
                    await PColorActor.shared.deleteColor(forPicWithID: picPendingDeletion.id)
                    deletedIDs.insert(picPendingDeletion.id)
                }
            }
            if let currentAlbum {
                AlbumCoverCache.shared.removeImages(forAlbumID: currentAlbum.id)
            }
            // Clear viewer state for deleted pics to prevent rendering stale data
            viewer.removePics(withIDs: deletedIDs)
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
        if let currentAlbum {
            AlbumCoverCache.shared.removeImages(forAlbumID: currentAlbum.id)
        }
        AlbumCoverCache.shared.removeImages(forAlbumID: album.id)
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
                    self.hasFetchedAlbums = true
                }
                await AlbumCoverCache.shared.loadCovers(for: albums)
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
                    withAnimation(.smooth.speed(2.0)) {
                        self.pics = pics
                    }
                    self.hasFetchedPics = true
                }
            }
        }
    }

    func fetchAlbums() async -> [Album] {
        do {
            return try await DataActor.shared.albumsWithCounts(in: currentAlbum, sortedBy: albumSort)
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
            await AlbumCoverCache.shared.loadCovers(for: albums)
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
            case .nameAscending:
                return try await DataActor.shared.picSkeletonsByName(
                    in: currentAlbum, order: .forward
                )
            case .nameDescending:
                return try await DataActor.shared.picSkeletonsByName(
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

        // Compute colors concurrently with bounded parallelism
        if !uncachedPics.isEmpty {
            let maxConcurrent = 8
            let newColors: [(picID: String, color: RGBColor)] = await withTaskGroup(
                of: (String, RGBColor?).self,
                returning: [(picID: String, color: RGBColor)].self
            ) { group in
                var iterator = uncachedPics.makeIterator()

                // Seed the group with initial batch
                for _ in 0..<min(maxConcurrent, uncachedPics.count) {
                    guard let pic = iterator.next() else { break }
                    group.addTask {
                        guard let thumbnailData = pic.thumbnailData else { return (pic.id, nil) }
                        let color = ProminentColor.calculate(from: thumbnailData)
                        return (pic.id, color)
                    }
                }

                // As each task completes, add the next one
                var results: [(picID: String, color: RGBColor)] = []
                for await (picID, color) in group {
                    if let color {
                        results.append((picID: picID, color: color))
                    }
                    if let pic = iterator.next() {
                        group.addTask {
                            guard let thumbnailData = pic.thumbnailData else { return (pic.id, nil) }
                            let color = ProminentColor.calculate(from: thumbnailData)
                            return (pic.id, color)
                        }
                    }
                }
                return results
            }
            for entry in newColors {
                colorsMap[entry.picID] = entry.color
            }
            await PColorActor.shared.storeColors(newColors)
        }

        // Sort by R, then G, then B
        let defaultColor = RGBColor(red: 128, green: 128, blue: 128)
        return pics.sorted { lhs, rhs in
            let colorA = colorsMap[lhs.id] ?? defaultColor
            let colorB = colorsMap[rhs.id] ?? defaultColor
            if colorA.red != colorB.red { return colorA.red < colorB.red }
            if colorA.green != colorB.green { return colorA.green < colorB.green }
            return colorA.blue < colorB.blue
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

    func updateBackgroundImage() async {
        guard let currentAlbum, currentAlbum.hasCoverPhoto,
              let coverPhoto = currentAlbum.coverPhoto else {
            await MainActor.run {
                backgroundImage = nil
            }
            return
        }
        let blurred = await Task.detached(priority: .utility) {
            Self.makeBlurredBackground(from: coverPhoto)
        }.value
        guard !Task.isCancelled else { return }
        await MainActor.run {
            backgroundImage = blurred
        }
    }

    private nonisolated static func makeBlurredBackground(from data: Data) -> UIImage? {
        guard let sourceImage = UIImage(data: data) else { return nil }
        // Downscale to a small size since this is just a blurry background
        let targetSize = CGSize(width: 64, height: 64)
        let scaledImage = sourceImage.scalePreservingAspectRatio(targetSize: targetSize)
        guard let ciImage = CIImage(image: scaledImage) else { return nil }
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = ciImage
        filter.radius = 10
        guard let outputImage = filter.outputImage else { return nil }
        let context = CIContext()
        // Crop to original extent since Gaussian blur expands the image
        let croppedOutput = outputImage.cropped(to: ciImage.extent)
        guard let cgImage = context.createCGImage(croppedOutput, from: croppedOutput.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
