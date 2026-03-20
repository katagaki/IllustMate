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
                importMenu
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
                    filterMenu
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

    @ViewBuilder
    var filterMenu: some View {
        Menu {
            Button(String(localized: "Duplicates.FindDuplicates", table: "Photos"),
                   systemImage: "photo.stack") {
                isDuplicateCheckerPresented = true
            }
            Section(String(localized: "Albums.Albums", table: "Albums")) {
                Picker(String(localized: "Albums.Style", table: "Albums"),
                       systemImage: "paintbrush",
                       selection: ($albumStyleState.animation(.smooth.speed(2.0)))) {
                    Label(String(localized: "Albums.Style.Grid", table: "Albums"),
                          systemImage: "square.grid.2x2")
                        .tag(ViewStyle.grid)
                    Label(String(localized: "Albums.Style.List", table: "Albums"),
                          systemImage: "list.bullet")
                        .tag(ViewStyle.list)
                    Label(String(localized: "Albums.Style.Carousel", table: "Albums"),
                          systemImage: "rectangle.on.rectangle")
                        .tag(ViewStyle.carousel)
                }
                .pickerStyle(.menu)
                if albumStyleState == .grid {
                    Picker("Shared.GridSize",
                           systemImage: "square.grid.2x2",
                           selection: $albumColumnCount.animation(.smooth.speed(2.0))) {
                        Text("Shared.GridSize.2")
                            .tag(2)
                        Text("Shared.GridSize.3")
                            .tag(3)
                        Text("Shared.GridSize.4")
                            .tag(4)
                    }
                    .pickerStyle(.menu)
                }
                Picker("Shared.Sort", systemImage: "arrow.up.arrow.down", selection: $albumSortState) {
                    Text("Shared.Sort.Name.Ascending")
                        .tag(SortType.nameAscending)
                    Text("Shared.Sort.Name.Descending")
                        .tag(SortType.nameDescending)
                    Text("Shared.Sort.PicCount.Ascending")
                        .tag(SortType.sizeAscending)
                    Text("Shared.Sort.PicCount.Descending")
                        .tag(SortType.sizeDescending)
                }
                .pickerStyle(.menu)
            }
            Section(String(localized: "Albums.Pics", table: "Albums")) {
                Picker("Shared.GridSize",
                       systemImage: "square.grid.2x2",
                       selection: $columnCount.animation(.smooth.speed(2.0))) {
                    Text("Shared.GridSize.3")
                        .tag(3)
                    Text("Shared.GridSize.4")
                        .tag(4)
                    Text("Shared.GridSize.5")
                        .tag(5)
                    Text("Shared.GridSize.8")
                        .tag(8)
                }
                .pickerStyle(.menu)
                Picker("Shared.Sort", systemImage: "arrow.up.arrow.down", selection: $picSortType) {
                    Text("Shared.Sort.DateAdded.Ascending")
                        .tag(PicSortType.dateAddedAscending)
                    Text("Shared.Sort.DateAdded.Descending")
                        .tag(PicSortType.dateAddedDescending)
                    Text("Shared.Sort.Name.Ascending")
                        .tag(PicSortType.nameAscending)
                    Text("Shared.Sort.Name.Descending")
                        .tag(PicSortType.nameDescending)
                    Text("Shared.Sort.ProminentColor")
                        .tag(PicSortType.prominentColor)
                }
                .pickerStyle(.menu)
            }
            Section {
                Toggle(String(localized: "Albums.HideHeaders", table: "Albums"),
                       isOn: $hideSectionHeaders)
            }
        } label: {
            Label("Shared.Filter", systemImage: "line.3.horizontal.decrease")
        }
        .menuActionDismissBehavior(.disabled)
        .menuOrder(.fixed)
    }

    @ViewBuilder
    var importMenu: some View {
        Menu("Shared.Import", systemImage: "square.and.arrow.down.on.square") {
            Section(String(localized: "Import.Section.FromPhotosApp", table: "Import")) {
                Button {
                    isPhotosPickerPresented = true
                } label: {
                    Label(String(localized: "Import.SelectPhotos", table: "Import"),
                          systemImage: "photo.on.rectangle.angled")
                }
                Button {
                    isBrowsingAlbums = true
                } label: {
                    Label(String(localized: "Import.BrowseAlbums", table: "Import"),
                          systemImage: "rectangle.stack")
                }
                Button {
                    isBrowsingFolders = true
                } label: {
                    Label(String(localized: "Import.SelectFolder", table: "Import"),
                          systemImage: "folder")
                }
            }
            Section(String(localized: "Import.Section.FromFilesApp", table: "Import")) {
                Button {
                    isFileImporterPresented = true
                } label: {
                    Label(String(localized: "Import.SelectFromFiles", table: "Import"),
                          systemImage: "folder")
                }
            }
        }
    }
}
