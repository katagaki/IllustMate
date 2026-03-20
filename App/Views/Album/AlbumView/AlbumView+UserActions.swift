//
//  AlbumView+UserActions.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import SwiftUI

extension AlbumView {

    func presentFileImporter() {
        #if targetEnvironment(macCatalyst)
        isFileImportSheetPresented = true
        #else
        isFileImporterPresented = true
        #endif
    }

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
}
