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
        .sheet(item: $albumToRename) { collection in
            photosRenameAlbumSheet(collection)
        }
        .sheet(item: $albumToMove) { collection in
            photosMoveFolderSheet(collection)
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

    // MARK: - Collection Content

    private var collectionContent: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
                photosAlbumsSection
                Spacer()
                    .frame(height: 20.0)
                photosPicsSection
            }
            .padding([.top], 20.0)
        }
        .onAppear {
            if !hasFetchedCollections {
                items = photosManager.fetchTopLevelCollections()
                hasFetchedCollections = true
            }
        }
        .task {
            if !hasFetchedRootAssets && !isFetchingRootAssets {
                isFetchingRootAssets = true
                rootAssets = await photosManager.fetchAssetsNotInAnyAlbum()
                hasFetchedRootAssets = true
                isFetchingRootAssets = false
            }
        }
    }

    private var photosAlbumsSection: some View {
        Group {
            SectionHeader(title: "Albums.Albums", count: items.count) {
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
            if !items.isEmpty {
                PhotosAlbumsSection(items: items, style: $albumStyleState,
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
            } else if hasFetchedCollections {
                Text("Albums.NoAlbums")
                    .foregroundStyle(.secondary)
                    .padding(20.0)
            }
        }
    }

    private var photosPicsSection: some View {
        Group {
            if !hasFetchedRootAssets {
                SectionHeader(title: "Albums.Pics", count: 0) { }
                    .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(20.0)
            } else if !rootAssets.isEmpty {
                SectionHeader(title: "Albums.Pics", count: rootAssets.count) {
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
                PhotosAssetsGrid(namespace: namespace, assets: rootAssets)
            }
        }
    }

    // MARK: - Access Denied

    private var photosAccessDeniedView: some View {
        VStack(spacing: 16.0) {
            Image(systemName: "photo.badge.exclamationmark")
                .resizable()
                .scaledToFit()
                .frame(width: 64.0, height: 64.0)
                .foregroundStyle(.secondary)
            Text("Import.PhotosAccessDenied")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Import.OpenSettings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(40.0)
    }

    // MARK: - Album Management Sheets

    private var photosNewAlbumSheet: some View {
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
                                _ = try await photosManager.createAlbum(named: newAlbumName)
                                await MainActor.run {
                                    newAlbumName = ""
                                    isAddingAlbum = false
                                    refreshCollections()
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
                                refreshCollections()
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
                refreshCollections()
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
                    refreshCollections()
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
                    refreshCollections()
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }

    private func refreshCollections() {
        items = photosManager.fetchTopLevelCollections()
    }
}

// MARK: - PHAssetCollection Identifiable conformance for sheet(item:)

extension PHAssetCollection: @retroactive Identifiable {
    public var id: String { localIdentifier }
}
