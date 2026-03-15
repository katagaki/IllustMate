//
//  AlbumView+Modifiers.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/15.
//

import Komponents
import SwiftUI

struct AlbumViewSheets: ViewModifier {
    @Binding var isAddingAlbum: Bool
    @Binding var albumToRename: Album?
    @Binding var isBrowsingAlbums: Bool
    @Binding var isImportingPhotos: Bool
    @Binding var isImportCompleted: Bool
    let importCurrentCount: Int
    let importTotalCount: Int
    let importCompletedCount: Int
    let currentAlbum: Album?
    let onAlbumDismiss: () -> Void
    let onBrowseAlbumsDismiss: () -> Void
    let onImportDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isAddingAlbum) {
                onAlbumDismiss()
            } content: {
                NewAlbumView(albumToAddTo: currentAlbum)
            }
            .sheet(item: $albumToRename) {
                onAlbumDismiss()
            } content: { album in
                RenameAlbumView(album: album)
            }
            .sheet(isPresented: $isBrowsingAlbums) {
                onBrowseAlbumsDismiss()
            } content: {
                NavigationStack {
                    PhotosAlbumPickerView(selectedAlbum: currentAlbum) {
                        isBrowsingAlbums = false
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(role: .cancel) {
                                isBrowsingAlbums = false
                            }
                        }
                    }
                }
                .phonePresentationDetents([.medium, .large])
                .interactiveDismissDisabled()
            }
            .sheet(isPresented: $isImportingPhotos) {
                onImportDismiss()
            } content: {
                ImportProgressView(
                    isImportCompleted: $isImportCompleted,
                    importCurrentCount: importCurrentCount,
                    importTotalCount: importTotalCount,
                    importCompletedCount: importCompletedCount
                )
            }
    }
}

struct AlbumViewDialogs: ViewModifier {
    @Binding var isConfirmingDeleteAlbum: Bool
    @Binding var isConfirmingDeletePic: Bool
    @Binding var isConfirmingDeleteSelectedPics: Bool
    @Binding var albumPendingDeletion: Album?
    @Binding var picPendingDeletion: Pic?
    let selectedPicsCount: Int
    let onConfirmDeleteAlbum: () -> Void
    let onConfirmDeletePic: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                Text("Shared.DeleteConfirmation.Album.\(albumPendingDeletion?.name ?? "")"),
                isPresented: $isConfirmingDeleteAlbum
            ) {
                Button("Shared.Yes", role: .destructive) {
                    onConfirmDeleteAlbum()
                }
                Button("Shared.No", role: .cancel) {
                    albumPendingDeletion = nil
                }
            } message: {
                Text("Shared.DeleteConfirmation.Album.Message")
            }
            .alert("Shared.DeleteConfirmation.Pic",
                   isPresented: $isConfirmingDeletePic) {
                Button("Shared.Yes", role: .destructive) {
                    onConfirmDeletePic()
                }
                Button("Shared.No", role: .cancel) {
                    picPendingDeletion = nil
                }
            }
            .alert("Shared.DeleteConfirmation.Pic.\(selectedPicsCount)",
                   isPresented: $isConfirmingDeleteSelectedPics) {
                Button("Shared.Yes", role: .destructive) {
                    onConfirmDeletePic()
                }
                Button("Shared.No", role: .cancel) {
                    picPendingDeletion = nil
                }
            }
    }
}
