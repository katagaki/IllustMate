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
    @EnvironmentObject var navigationManager: NavigationManager
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

    @State var illustrations: [Illustration] = []
    @State var isConfirmingDeleteIllustration: Bool = false
    @State var isConfirmingDeleteSelectedIllustrations: Bool = false
    @State var illustrationPendingDeletion: Illustration?
    @State var isSelectingIllustrations: Bool = false
    @State var selectedIllustrations: [Illustration] = []
    @State var isImportingPhotos: Bool = false
    @AppStorage(wrappedValue: false, "IllustrationSortReversed") var isIllustrationSortReversed: Bool

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
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
                SectionHeader(title: "Albums.Pictures", count: illustrations.count) {
                    Button("Shared.Import", systemImage: "square.and.arrow.down.on.square") {
                        isImportingPhotos = true
                    }
                    Divider()
                    Picker("Shared.Sort", systemImage: "arrow.up.arrow.down", selection: $isIllustrationSortReversed) {
                        Text("Shared.Sort.DateAdded.Ascending")
                            .tag(true)
                        Text("Shared.Sort.DateAdded.Descending")
                            .tag(false)
                    }
                    .pickerStyle(.menu)
                }
                .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
                if !illustrations.isEmpty {
                    IllustrationsGrid(namespace: namespace, illustrations: illustrations,
                                      isSelecting: $isSelectingIllustrations) { illustration in
                        selectedIllustrations.contains(illustration)
                    } onSelect: { illustration in
                        selectOrDeselectIllustration(illustration)
                    } selectedCount: {
                        selectedIllustrations.count
                    } onDelete: { illustration in
                        deleteIllustration(illustration)
                    } moveMenu: { illustration in
                        IllustrationMoveMenu(illustrations: isSelectingIllustrations ?
                                             selectedIllustrations : [illustration],
                                             containingAlbum: currentAlbum) {
                            refreshDataAfterIllustrationMoved()
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Shared.Select", systemImage: "checkmark.circle") {
                    startOrStopSelectingIllustrations()
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Shared.Create", systemImage: "plus") {
                    isAddingAlbum = true
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
            if isSelectingIllustrations, !illustrations.isEmpty {
                SelectionBar(illustrations: illustrations, selectedIllustrations: $selectedIllustrations) {
                    startOrStopSelectingIllustrations()
                } menuItems: {
                    Menu("Shared.Move", systemImage: "tray.full") {
                        IllustrationMoveMenu(illustrations: selectedIllustrations, containingAlbum: currentAlbum) {
                            refreshDataAfterIllustrationMoved()
                        }
                    }
                    Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                        deleteIllustrations()
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
            refreshIllustrationsAndSet()
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
                            isPresented: $isConfirmingDeleteIllustration, titleVisibility: .visible) {
            Button("Shared.Yes", role: .destructive) {
                confirmDeleteIllustration()
            }
            Button("Shared.No", role: .cancel) {
                illustrationPendingDeletion = nil
            }
        }
        .confirmationDialog("Shared.DeleteConfirmation.Picture.\(selectedIllustrations.count)",
                            isPresented: $isConfirmingDeleteSelectedIllustrations, titleVisibility: .visible) {
            Button("Shared.Yes", role: .destructive) {
                confirmDeleteIllustration()
            }
            Button("Shared.No", role: .cancel) {
                illustrationPendingDeletion = nil
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
        .onChange(of: isIllustrationSortReversed) { _, _ in
            refreshIllustrationsAndSet()
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
