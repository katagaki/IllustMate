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
            if useThreadSafeLoading {
                Task.detached(priority: .userInitiated) {
                    await actor.deleteAlbum(withIdentifier: albumPendingDeletion.persistentModelID)
                }
            } else {
                modelContext.delete(albumPendingDeletion)
            }
            doWithAnimation {
                refreshData()
            }
        }
    }

    func refreshDataAfterAlbumMoved() {
        doWithAnimation {
            refreshAlbums()
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
        if isSelectingIllustrations {
            for illustration in selectedIllustrations {
                if useThreadSafeLoading {
                    Task.detached(priority: .userInitiated) {
                        await actor.deleteIllustration(withIdentifier: illustration.persistentModelID)
                    }
                } else {
                    if !deleteWithoutFile {
                        illustration.prepareForDeletion()
                    }
                    modelContext.delete(illustration)
                }
            }
        } else {
            if let illustrationPendingDeletion {
                if useThreadSafeLoading {
                    Task.detached(priority: .userInitiated) {
                        await actor.deleteIllustration(withIdentifier: illustrationPendingDeletion.persistentModelID)
                    }
                } else {
                    if !deleteWithoutFile {
                        illustrationPendingDeletion.prepareForDeletion()
                    }
                    modelContext.delete(illustrationPendingDeletion)
                }
            }
        }
        doWithAnimation {
            refreshIllustrations()
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
        if !useThreadSafeLoading {
            doWithAnimation {
                refreshData()
            }
        }
    }

    func moveIllustrationsToAlbum(_ illustrations: [Illustration], to album: Album) {
        if useThreadSafeLoading {
            Task.detached(priority: .userInitiated) {
                for illustration in illustrations {
                    await actor.addIllustration(withIdentifier: illustration.persistentModelID,
                                                toAlbumWithIdentifier: album.persistentModelID)
                    await refreshData(animated: true)
                }
            }
        } else {
            album.addChildIllustrations(illustrations)
        }
    }

    func moveAlbumsToAlbum(_ albums: [Album], to album: Album) {
        if !albums.contains(where: { $0.id == album.id }) {
            if useThreadSafeLoading {
                Task.detached(priority: .userInitiated) {
                    for destinationAlbum in albums {
                        await actor.addAlbum(withIdentifier: destinationAlbum.persistentModelID,
                                             toAlbumWithIdentifier: album.persistentModelID)
                    }
                    await refreshData(animated: true)
                }
            } else {
                album.addChildAlbums(albums)
            }
        }
    }

    func importPhotoToAlbum(_ photo: Image, to album: Album) {
        // TODO: Import photo dropped from outside app
    }

    func refreshDataAfterIllustrationMoved() {
        selectedIllustrations.removeAll()
        doWithAnimation {
            refreshIllustrations()
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

    func refreshData(animated: Bool = true) {
        refreshAlbums(animated: animated)
        refreshIllustrations(animated: animated)
    }

    func refreshAlbums(animated: Bool = true) {
        if useThreadSafeLoading {
            refreshAlbumsUsingActor(animated: animated)
        } else {
            let currentAlbumID = currentAlbum?.id
            do {
                albums = try modelContext.fetch(FetchDescriptor<Album>(
                    predicate: #Predicate { $0.parentAlbum?.id == currentAlbumID },
                    sortBy: [SortDescriptor(\.name)]))
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }

    func refreshAlbumsUsingActor(animated: Bool = true) {
        Task.detached(priority: .userInitiated) {
            do {
                let albums = try await actor.albums(in: currentAlbum)
                await MainActor.run {
                    if animated {
                        doWithAnimation {
                            self.albums = albums
                        }
                    } else {
                        self.albums = albums
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }

    func refreshIllustrations(animated: Bool = true) {
        if useThreadSafeLoading {
            refreshIllustrationsUsingActor(animated: animated)
        } else {
            let currentAlbumID = currentAlbum?.id
            do {
                var fetchDescriptor = FetchDescriptor<Illustration>(
                    predicate: #Predicate { $0.containingAlbum?.id == currentAlbumID },
                    sortBy: [SortDescriptor(\.dateAdded, order: isIllustrationSortReversed ? .forward : .reverse)])
                fetchDescriptor.propertiesToFetch = [\.name, \.dateAdded]
                fetchDescriptor.relationshipKeyPathsForPrefetching = [\.cachedThumbnail]
                illustrations = try modelContext.fetch(fetchDescriptor)
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }

    func refreshIllustrationsUsingActor(animated: Bool = true) {
        Task.detached(priority: .userInitiated) {
            do {
                let illustrations = try await actor
                    .illustrations(in: currentAlbum, order: isIllustrationSortReversed ? .forward : .reverse)
                await MainActor.run {
                    if animated {
                        doWithAnimation {
                            self.illustrations = illustrations
                        }
                    } else {
                        self.illustrations = illustrations
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
}
