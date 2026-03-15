//
//  PhotosFolderView.swift
//  PicMate
//
//  Created on 2026/02/26.
//

import Photos
import SwiftUI

struct PhotosFolderView: View {

    @Environment(PhotosManager.self) var photosManager

    let folder: PHCollectionList

    @AppStorage("PhotosNestedAlbumsEnabled",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var isNestedAlbumsEnabled: Bool = false

    @Namespace var namespace

    @State var items: [PHCollectionItem] = []
    @State var ownPicsFetchResult: PHFetchResult<PHAsset>?
    @State var hasFetched: Bool = false
    @State var searchText: String = ""

    @State var searchResults: [PHCollectionItem]?

    var filteredItems: [PHCollectionItem] {
        if searchText.isEmpty {
            return items
        }
        return searchResults ?? []
    }

    // Album management state
    @State var albumToRename: PHAssetCollection?
    @State var renameText: String = ""
    @State var albumToDelete: PHAssetCollection?
    @State var folderToDelete: PHCollectionList?
    @State var albumToMove: PHAssetCollection?
    @State var isConfirmingDeleteAlbum: Bool = false
    @State var isConfirmingDeleteFolder: Bool = false
    @State var isAddingAlbum: Bool = false
    @State var newAlbumName: String = ""
    @State var coverRefreshID: Int = 0

    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumStyleState: ViewStyle
    @AppStorage(wrappedValue: 3, "AlbumColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumColumnCount: Int
    @AppStorage(wrappedValue: 4, "PicColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var picColumnCount: Int

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
                if !filteredItems.isEmpty {
                    albumsSection
                    if searchText.isEmpty {
                        Spacer()
                            .frame(height: 20.0)
                    }
                }

                if searchText.isEmpty,
                   isNestedAlbumsEnabled, let fetchResult = ownPicsFetchResult, fetchResult.count > 0 {
                    picsSection(fetchResult: fetchResult)
                }
            }
            .padding([.top], 20.0)
        }
        .navigationTitle(folder.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
        .searchable(text: $searchText)
        .onChange(of: searchText) { _, newValue in
            withAnimation(.smooth.speed(2.0)) {
                if newValue.isEmpty {
                    searchResults = nil
                } else {
                    searchResults = photosManager.searchAlbums(matching: newValue)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Shared.Create", systemImage: "rectangle.stack.badge.plus") {
                    isAddingAlbum = true
                }
            }
            if UIDevice.current.userInterfaceIdiom == .phone {
                ToolbarItemGroup(placement: .bottomBar) {
                    photosFilterMenu
                }
                ToolbarSpacer(.fixed, placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            }
        }
        .onAppear {
            if !hasFetched {
                fetchContent()
            }
        }
        .sheet(isPresented: $isAddingAlbum) {
            photosNewAlbumInFolderSheet
        }
        .sheet(isPresented: Binding(
            get: { albumToRename != nil },
            set: { if !$0 { albumToRename = nil } }
        )) {
            if let collection = albumToRename {
                photosRenameAlbumSheet(collection)
            }
        }
        .sheet(isPresented: Binding(
            get: { albumToMove != nil },
            set: { if !$0 { albumToMove = nil } }
        )) {
            if let collection = albumToMove {
                photosMoveFolderSheet(collection)
            }
        }
        .confirmationDialog("Shared.DeleteConfirmation.Album",
                            isPresented: $isConfirmingDeleteAlbum, titleVisibility: .visible) {
            Button("Shared.Yes", role: .destructive) {
                confirmDeletePhotosAlbum()
            }
            Button("Shared.No", role: .cancel) {
                albumToDelete = nil
            }
        }
        .confirmationDialog("Shared.DeleteConfirmation.Album",
                            isPresented: $isConfirmingDeleteFolder, titleVisibility: .visible) {
            Button("Shared.Yes", role: .destructive) {
                confirmDeletePhotosFolder()
            }
            Button("Shared.No", role: .cancel) {
                folderToDelete = nil
            }
        }
    }

    @ViewBuilder
    private var photosFilterMenu: some View {
        Menu {
            ControlGroup {
                Picker("Albums.Style",
                       selection: $albumStyleState.animation(.smooth.speed(2))) {
                    Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                        .tag(ViewStyle.grid)
                    Label("Albums.Style.List", systemImage: "list.bullet")
                        .tag(ViewStyle.list)
                    Label("Albums.Style.Carousel", systemImage: "rectangle.on.rectangle")
                        .tag(ViewStyle.carousel)
                }
            }
            Section("Albums.Albums") {
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
            }
            Section("Albums.Pics") {
                Picker("Shared.GridSize",
                       systemImage: "square.grid.2x2",
                       selection: $picColumnCount.animation(.smooth.speed(2.0))) {
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
            }
        } label: {
            Label("Shared.Filter", systemImage: "line.3.horizontal.decrease")
        }
        .menuActionDismissBehavior(.disabled)
    }
}
