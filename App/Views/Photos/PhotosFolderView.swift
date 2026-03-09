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

    @State private var items: [PHCollectionItem] = []
    @State private var ownPicsFetchResult: PHFetchResult<PHAsset>?
    @State private var hasFetched: Bool = false
    @State private var searchText: String = ""

    private var filteredItems: [PHCollectionItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
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
                    Spacer()
                        .frame(height: 20.0)
                }

                if isNestedAlbumsEnabled, let fetchResult = ownPicsFetchResult, fetchResult.count > 0 {
                    picsSection(fetchResult: fetchResult)
                }
            }
            .padding([.top], 20.0)
        }
        .navigationTitle(folder.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Shared.Create", systemImage: "rectangle.stack.badge.plus") {
                    isAddingAlbum = true
                }
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

    // MARK: - Sections

    private var albumsSection: some View {
        Group {
            SectionHeader(title: "Albums.Albums", count: filteredItems.count) {
                Picker("Albums.Style",
                       selection: $albumStyleState.animation(.smooth.speed(2))) {
                    Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                        .tag(ViewStyle.grid)
                    Label("Albums.Style.List", systemImage: "list.bullet")
                        .tag(ViewStyle.list)
                    Label("Albums.Style.Carousel", systemImage: "rectangle.on.rectangle")
                        .tag(ViewStyle.carousel)
                }
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
            .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
            PhotosAlbumsSection(items: filteredItems, style: $albumStyleState,
                                onRename: { collection in
                                    albumToRename = collection
                                },
                                onDelete: { collection in
                                    albumToDelete = collection
                                    isConfirmingDeleteAlbum = true
                                },
                                onMoveToFolder: { collection in
                                    albumToMove = collection
                                },
                                onDeleteFolder: { folder in
                                    folderToDelete = folder
                                    isConfirmingDeleteFolder = true
                                })
        }
    }

    private func picsSection(fetchResult: PHFetchResult<PHAsset>) -> some View {
        Group {
            SectionHeader(title: "Albums.Pics", count: fetchResult.count) {
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
            .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
            PhotosFetchResultAssetsGrid(namespace: namespace, fetchResult: fetchResult)
        }
    }

    // MARK: - Data

    private func fetchContent() {
        if isNestedAlbumsEnabled {
            let resolved = photosManager.resolveNestedAlbums(in: folder)

            var collected: [PHCollectionItem] = []
            for album in resolved.albums {
                collected.append(.album(album))
            }
            for subfolder in resolved.folders {
                collected.append(.folder(subfolder))
            }
            items = collected

            if let ownPicsCollection = resolved.ownPicsCollection {
                ownPicsFetchResult = photosManager.fetchAssets(in: ownPicsCollection)
            }
        } else {
            items = photosManager.fetchCollections(in: folder)
        }
        hasFetched = true
    }

    // MARK: - Album Management Sheets

    private var photosNewAlbumInFolderSheet: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Albums.Create.Placeholder", text: $newAlbumName)
                        .textInputAutocapitalization(.words)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        newAlbumName = ""
                        isAddingAlbum = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        Task {
                            do {
                                let newAlbum = try await photosManager.createAlbum(named: newAlbumName)
                                try await photosManager.moveAlbum(newAlbum, into: folder)
                                await MainActor.run {
                                    newAlbumName = ""
                                    isAddingAlbum = false
                                    hasFetched = false
                                    fetchContent()
                                }
                            } catch {
                                debugPrint(error.localizedDescription)
                            }
                        }
                    }
                    .disabled(newAlbumName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("ViewTitle.Albums.Create")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(200.0)])
        .interactiveDismissDisabled()
    }

    private func photosRenameAlbumSheet(_ collection: PHAssetCollection) -> some View {
        NavigationStack {
            List {
                Section {
                    TextField(collection.localizedTitle ?? "", text: $renameText)
                        .textInputAutocapitalization(.words)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task {
                        do {
                            try await photosManager.renameAlbum(collection, to: renameText)
                            await MainActor.run {
                                albumToRename = nil
                                renameText = ""
                                hasFetched = false
                                fetchContent()
                            }
                        } catch {
                            debugPrint(error.localizedDescription)
                        }
                    }
                } label: {
                    Text("Shared.Rename")
                        .bold()
                        .padding(4.0)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
                .frame(maxWidth: .infinity)
                .padding(20.0)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        albumToRename = nil
                        renameText = ""
                    }
                }
            }
            .navigationTitle("ViewTitle.Albums.Rename")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            renameText = collection.localizedTitle ?? ""
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private func photosMoveFolderSheet(_ collection: PHAssetCollection) -> some View {
        NavigationStack {
            PhotosFolderPickerView(album: collection) {
                albumToMove = nil
                hasFetched = false
                fetchContent()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        albumToMove = nil
                    }
                }
            }
            .navigationTitle("Photos.MoveToFolder")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Actions

    private func confirmDeletePhotosAlbum() {
        guard let album = albumToDelete else { return }
        Task {
            do {
                try await photosManager.deleteAlbum(album)
                await MainActor.run {
                    albumToDelete = nil
                    hasFetched = false
                    fetchContent()
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }

    private func confirmDeletePhotosFolder() {
        guard let folder = folderToDelete else { return }
        Task {
            do {
                try await photosManager.deleteFolder(folder)
                await MainActor.run {
                    folderToDelete = nil
                    hasFetched = false
                    fetchContent()
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
}
