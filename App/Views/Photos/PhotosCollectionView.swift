//
//  PhotosCollectionView.swift
//  PicMate
//
//  Created on 2026/02/26.
//

import Photos
import SwiftUI

struct PhotosCollectionView: View {
    @Environment(PhotosManager.self) var photosManager
    @EnvironmentObject var navigation: NavigationManager

    @Namespace var namespace

    @State var items: [PHCollectionItem] = []
    @State var rootAssets: [PHAsset] = []
    @State var hasFetchedCollections: Bool = false
    @State var hasFetchedRootAssets: Bool = false
    @State var isFetchingRootAssets: Bool = false
    @State var searchText: String = ""

    @State var searchResults: [PHCollectionItem]?

    var filteredItems: [PHCollectionItem] {
        if searchText.isEmpty {
            return items
        }
        return searchResults ?? []
    }

    // Album management state
    @State var isAddingAlbum: Bool = false
    @State var newAlbumName: String = ""
    @State var albumToRename: PHAssetCollection?
    @State var renameText: String = ""
    @State var albumToDelete: PHAssetCollection?
    @State var folderToDelete: PHCollectionList?
    @State var albumToMove: PHAssetCollection?
    @State var isConfirmingDeleteAlbum: Bool = false
    @State var isConfirmingDeleteFolder: Bool = false
    @State var coverRefreshID: Int = 0

    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumStyleState: ViewStyle
    @AppStorage(wrappedValue: 3, "AlbumColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumColumnCount: Int
    @AppStorage(wrappedValue: 4, "PicColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var picColumnCount: Int

    var body: some View {
        Group {
            switch photosManager.authorizationStatus {
            case .authorized, .limited:
                collectionContent
            case .denied, .restricted:
                photosAccessDeniedView
            default:
                ProgressView()
                    .onAppear {
                        photosManager.requestAuthorization()
                    }
            }
        }
        .navigationTitle(String(localized: "ViewTitle.Photos"))
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
            if photosManager.authorizationStatus == .authorized ||
               photosManager.authorizationStatus == .limited {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Shared.Create", systemImage: "rectangle.stack.badge.plus") {
                        isAddingAlbum = true
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingAlbum) {
            photosNewAlbumSheet
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
}
