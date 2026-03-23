//
//  AlbumView+Toolbar.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/15.
//

import Komponents
import SwiftUI
import TipKit

extension AlbumView {

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        if isSelectingPics {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    startOrStopSelectingPics()
                } label: {
                    Image(systemName: "xmark")
                }
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItemGroup(placement: .bottomBar) {
                Menu("Shared.Move", systemImage: "tray.full") {
                    PicMoveMenu(pics: selectedPics, containingAlbum: currentAlbum) {
                        refreshDataAfterPicMoved()
                    }
                }
                .disabled(selectedPics.isEmpty)
                Text("Shared.Selected.\(selectedPics.count)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .fixedSize()
                Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                    deletePics()
                }
                .disabled(selectedPics.isEmpty)
                .tint(.red)
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    selectOrDeselectAllPics()
                } label: {
                    if pics.count == selectedPics.count {
                        Label("Shared.DeselectAll", image: "checkmark.circle.slash")
                    } else {
                        Label("Shared.SelectAll", systemImage: "checkmark.circle")
                    }
                }
            }
        } else {
            if UIDevice.current.userInterfaceIdiom != .phone {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Shared.Select") {
                        startOrStopSelectingPics()
                    }
                    .disabled(pics.isEmpty)
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                AlbumImportMenu(
                    isPhotosPickerPresented: $isPhotosPickerPresented,
                    isBrowsingAlbums: $isBrowsingAlbums,
                    isBrowsingFolders: $isBrowsingFolders,
                    presentFileImporter: presentFileImporter
                )
                .popoverTip(ImportTip(), arrowEdge: .top) { _ in
                    NewAlbumTip.hasSeenImportTip = true
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Shared.Create", systemImage: "rectangle.stack.badge.plus") {
                    isAddingAlbum = true
                }
                .popoverTip(NewAlbumTip(), arrowEdge: .top) { _ in
                    LibrariesTip.hasSeenNewAlbumTip = true
                }
            }
            if UIDevice.current.userInterfaceIdiom == .phone {
                ToolbarItemGroup(placement: .bottomBar) {
                    AlbumFilterMenu(
                        isDuplicateCheckerPresented: $isDuplicateCheckerPresented,
                        albumStyleState: $albumStyleState,
                        albumColumnCount: $albumColumnCount,
                        albumSortState: $albumSortState,
                        columnCount: $columnCount,
                        picSortType: $picSortType,
                        hideSectionHeaders: $hideSectionHeaders
                    )
                }
                ToolbarSpacer(.fixed, placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(.fixed, placement: .bottomBar)
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Shared.Select") {
                        startOrStopSelectingPics()
                    }
                    .disabled(pics.isEmpty)
                }
            }
        }
    }
}
