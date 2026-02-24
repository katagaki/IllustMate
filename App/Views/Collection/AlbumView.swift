//
//  AlbumView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftUI

struct AlbumView: View {

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var navigation: NavigationManager
    @Environment(ViewerManager.self) var viewer

    @Namespace var namespace

    var currentAlbum: Album?
    @State var albums: [Album] = []
    @State var isConfirmingDeleteAlbum: Bool = false
    @State var albumPendingDeletion: Album?
    @State var isAddingAlbum: Bool = false
    @State var albumToRename: Album?
    @AppStorage(wrappedValue: SortType.nameAscending, "AlbumSort",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumSort: SortType
    @State var albumSortState: SortType = .nameAscending
    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumStyle: ViewStyle
    @State var albumStyleState: ViewStyle = .grid

    @State var pics: [Pic] = []
    @State var isConfirmingDeletePic: Bool = false
    @State var isConfirmingDeleteSelectedPics: Bool = false
    @State var picPendingDeletion: Pic?
    @State var isSelectingPics: Bool = false
    @State var selectedPics: [Pic] = []
    @State var isImportingPhotos: Bool = false
    @AppStorage(wrappedValue: false, "PicSortReversed") var isPicSortReversed: Bool

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
                if !isSelectingPics {
                    SectionHeader(title: "Albums.Albums", count: albums.count) {
                        Picker("Albums.Style", selection: ($albumStyleState.animation(.smooth.speed(2)))) {
                            Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                                .tag(ViewStyle.grid)
                            Label("Albums.Style.List", systemImage: "list.bullet")
                                .tag(ViewStyle.list)
                        }
                        Picker("Shared.Sort", systemImage: "arrow.up.arrow.down", selection: $albumSortState) {
                            Text("Shared.Sort.Name.Ascending")
                                .tag(SortType.nameAscending)
                            Text("Shared.Sort.Name.Descending")
                                .tag(SortType.nameDescending)
                            Text("Shared.Sort.PictureCount.Ascending")
                                .tag(SortType.sizeAscending)
                            Text("Shared.Sort.PictureCount.Descending")
                                .tag(SortType.sizeDescending)
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
                    if !albums.isEmpty {
                        AlbumsSection(albums: albums, style: $albumStyleState) { album in
                            albumToRename = album
                        } onDelete: { album in
                            deleteAlbum(album)
                        } onDrop: { transferable, album in
                            moveDropToAlbum(transferable, to: album)
                        } moveMenu: { album in
                            AlbumMoveMenu(album: album) {
                                refreshAlbumsAndSet()
                            }
                        }
                    } else {
                        Text("Albums.NoAlbums")
                            .foregroundStyle(.secondary)
                            .padding(20.0)
                    }
                    Spacer()
                        .frame(height: 20.0)
                }
                SectionHeader(title: "Albums.Pictures", count: pics.count) {
                    Button("Shared.Import", systemImage: "square.and.arrow.down.on.square") {
                        isImportingPhotos = true
                    }
                    Divider()
                    Picker("Shared.Sort", systemImage: "arrow.up.arrow.down", selection: $isPicSortReversed) {
                        Text("Shared.Sort.DateAdded.Ascending")
                            .tag(true)
                        Text("Shared.Sort.DateAdded.Descending")
                            .tag(false)
                    }
                    .pickerStyle(.menu)
                }
                .disabled(isSelectingPics)
                .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
                if !pics.isEmpty {
                    PicsGrid(namespace: namespace, pics: pics,
                                      isSelecting: $isSelectingPics) { pic in
                        selectedPics.contains(pic)
                    } onSelect: { pic in
                        selectOrDeselectPic(pic)
                    } selectedCount: {
                        selectedPics.count
                    } onDelete: { pic in
                        deletePic(pic)
                    } moveMenu: { pic in
                        PicMoveMenu(pics: isSelectingPics ?
                                             selectedPics : [pic],
                                             containingAlbum: currentAlbum) {
                            refreshDataAfterPicMoved()
                        }
                    }
                } else {
                    Text("Albums.NoPictures")
                        .foregroundStyle(.secondary)
                        .padding(20.0)
                }
            }
            .padding([.top], 20.0)
        }
        .toolbar {
            if !isSelectingPics {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Shared.Select") {
                        startOrStopSelectingPics()
                    }
                    .disabled(pics.isEmpty)
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Shared.Create", systemImage: "rectangle.stack.badge.plus") {
                        isAddingAlbum = true
                    }
                }
            }
        }
#if targetEnvironment(macCatalyst)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Shared.Refresh") {
                    Task {
                        await refreshData()
                    }
                }
            }
        }
#else
        .refreshable {
            await refreshData()
        }
#endif
        .safeAreaInset(edge: .bottom) {
            if isSelectingPics {
                SelectionBar(pics: pics, selectedPics: $selectedPics) {
                    startOrStopSelectingPics()
                } menuItems: {
                    Menu("Shared.Move", systemImage: "tray.full") {
                        PicMoveMenu(pics: selectedPics, containingAlbum: currentAlbum) {
                            refreshDataAfterPicMoved()
                        }
                    }
                    Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                        deletePics()
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingAlbum) {
            refreshAlbumsAndSet()
        } content: {
            NewAlbumView(albumToAddTo: currentAlbum)
        }
        .sheet(item: $albumToRename) {
            refreshAlbumsAndSet()
        } content: { album in
            RenameAlbumView(album: album)
        }
        .sheet(isPresented: $isImportingPhotos) {
            refreshPicsAndSet()
        } content: {
            ImporterView(selectedAlbum: currentAlbum)
        }
        .confirmationDialog("Shared.DeleteConfirmation.Album",
                            isPresented: $isConfirmingDeleteAlbum, titleVisibility: .visible) {
            Button("Shared.Yes", role: .destructive) {
                confirmDeleteAlbum()
            }
            Button("Shared.No", role: .cancel) {
                albumPendingDeletion = nil
            }
        }
        .confirmationDialog("Shared.DeleteConfirmation.Picture",
                            isPresented: $isConfirmingDeletePic, titleVisibility: .visible) {
            Button("Shared.Yes", role: .destructive) {
                confirmDeletePic()
            }
            Button("Shared.No", role: .cancel) {
                picPendingDeletion = nil
            }
        }
        .confirmationDialog("Shared.DeleteConfirmation.Picture.\(selectedPics.count)",
                            isPresented: $isConfirmingDeleteSelectedPics, titleVisibility: .visible) {
            Button("Shared.Yes", role: .destructive) {
                confirmDeletePic()
            }
            Button("Shared.No", role: .cancel) {
                picPendingDeletion = nil
            }
        }
        .onAppear {
            albumStyleState = albumStyle
            albumSortState = albumSort
            Task.detached(priority: .userInitiated) {
                await refreshData()
            }
        }
        .onChange(of: albumStyleState) { _, newValue in
            albumStyle = newValue
        }
        .onChange(of: albumSortState) { _, newValue in
            albumSort = newValue
        }
        .onChange(of: albumSort) { _, _ in
            refreshAlbumsAndSet()
        }
        .onChange(of: isPicSortReversed) { _, _ in
            refreshPicsAndSet()
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                Task.detached(priority: .userInitiated) {
                    await refreshData()
                }
            }
        }
        .navigationTitle(currentAlbum?.name ?? String(localized: "ViewTitle.Collection"))
    }

}
