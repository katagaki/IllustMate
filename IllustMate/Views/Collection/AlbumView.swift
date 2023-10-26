//
//  AlbumView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftData
import SwiftUI

struct AlbumView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var navigationManager: NavigationManager

    var namespace: Namespace.ID

    @State var isDataLoadedFromInitialAppearance: Bool = false

    var currentAlbum: Album?
    @State var albums: [Album]?
    @State var isConfirmingDeleteAlbum: Bool = false
    @State var albumPendingDeletion: Album?
    @State var isAddingAlbum: Bool = false
    @State var albumToRename: Album?
    @AppStorage(wrappedValue: SortType.nameAscending, "AlbumSort", store: defaults) var albumSort: SortType
    @State var albumSortState: SortType = .nameAscending
    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle", store: defaults) var style: ViewStyle
    @State var styleState: ViewStyle = .grid

    @State var illustrations: [Illustration]?
    @State var isConfirmingDeleteIllustration: Bool = false
    @State var isConfirmingDeleteSelectedIllustrations: Bool = false
    @State var illustrationPendingDeletion: Illustration?
    @State var isSelectingIllustrations: Bool = false
    @State var selectedIllustrations: [Illustration] = []
    @State var isImportingPhotos: Bool = false
    @Binding var viewerManager: ViewerManager
    @AppStorage(wrappedValue: false, "IllustrationSortReversed") var isIllustrationSortReversed: Bool
    @AppStorage(wrappedValue: false, "DebugDeleteWithoutFile") var deleteWithoutFile: Bool

    @AppStorage(wrappedValue: false, "DebugAllAnimsOff") var disableAllAnimations: Bool

    let actor = DataActor(modelContainer: sharedModelContainer)

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
                SectionHeader(title: "Albums.Albums", count: albums?.count ?? 0) {
                    Button("Shared.Create", systemImage: "plus") {
                        isAddingAlbum = true
                    }
                    Picker("Shared.Sort", selection: $albumSortState) {
                        Label("Shared.Sort.Name.Ascending", image: "Sort.Name.Ascending")
                            .tag(SortType.nameAscending)
                        Label("Shared.Sort.Name.Descending", image: "Sort.Name.Descending")
                            .tag(SortType.nameDescending)
                        Label("Shared.Sort.IllustrationCount.Ascending", image: "Sort.Count.Ascending")
                            .tag(SortType.illustrationCountAscending)
                        Label("Shared.Sort.IllustrationCount.Descending", image: "Sort.Count.Descending")
                            .tag(SortType.illustrationCountDescending)
                    }
                    if disableAllAnimations {
                        Picker("Albums.Style", selection: $styleState) {
                            Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                                .tag(ViewStyle.grid)
                            Label("Albums.Style.List", systemImage: "list.bullet")
                                .tag(ViewStyle.list)
                        }
                    } else {
                        Picker("Albums.Style", selection: $styleState.animation(.snappy.speed(2))) {
                            Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                                .tag(ViewStyle.grid)
                            Label("Albums.Style.List", systemImage: "list.bullet")
                                .tag(ViewStyle.list)
                        }
                    }
                }
                .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
                if let albums {
                    if !albums.isEmpty {
                        Divider()
                            .padding([.leading], colorScheme == .light ? 0.0 : 20.0)
                        AlbumsSection(albums: albums, style: $styleState) { album in
                            albumToRename = album
                        } onDelete: { album in
                            deleteAlbum(album)
                        } onDrop: { transferable, album in
                            moveDropToAlbum(transferable, to: album)
                        } moveMenu: { album in
                            AlbumMoveMenu(album: album) {
                                Task.detached(priority: .userInitiated) {
                                    await refreshAlbums()
                                }
                            }
                        }
                        if colorScheme == .light || styleState == .list {
                            Divider()
                        }
                    } else {
                        Divider()
                            .padding([.leading], 20.0)
                        Text("Albums.NoAlbums")
                            .foregroundStyle(.secondary)
                            .padding(20.0)
                    }
                } else {
                    Divider()
                        .padding([.leading], 20.0)
                    ProgressView()
                        .padding(20.0)
                }
                Spacer()
                    .frame(height: 20.0)
                SectionHeader(title: "Albums.Illustrations", count: illustrations?.count ?? 0) {
                    Button("Shared.Select", systemImage: "checkmark.circle") {
                        startOrStopSelectingIllustrations()
                    }
                    .disabled(isSelectingIllustrations || illustrations == nil || (illustrations?.isEmpty ?? true))
                    Picker("Shared.Sort", selection: $isIllustrationSortReversed) {
                        Label("Shared.Sort.DateAdded.Ascending", image: "Sort.Count.Ascending")
                            .tag(true)
                        Label("Shared.Sort.DateAdded.Descending", image: "Sort.Count.Descending")
                            .tag(false)
                    }
                    Button("Shared.Import", systemImage: "square.and.arrow.down.on.square") {
                        isImportingPhotos = true
                    }
                }
                .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
                if let illustrations {
                    if !illustrations.isEmpty {
                        Divider()
                        IllustrationsGrid(namespace: namespace, illustrations: illustrations,
                                          isSelecting: $isSelectingIllustrations) { illustration in
                            illustration.id == viewerManager.displayedIllustrationID
                        } isSelected: { illustration in
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
                        Divider()
                    } else {
                        Divider()
                            .padding([.leading], 20.0)
                        Text("Albums.NoIllustrations")
                            .foregroundStyle(.secondary)
                            .padding(20.0)
                    }
                } else {
                    Divider()
                        .padding([.leading], 20.0)
                    ProgressView()
                        .padding(20.0)
                }
            }
            .padding([.top], 20.0)
        }
        .background(Color.init(uiColor: .systemGroupedBackground))
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
            doWithAnimation {
                albums?.removeAll()
                illustrations?.removeAll()
            } completion: {
                Task {
                    await refreshData()
                }
            }
        }
#endif
        .safeAreaInset(edge: .bottom) {
            if isSelectingIllustrations, let illustrations {
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
            Task.detached(priority: .userInitiated) {
                await refreshAlbums()
            }
        } content: {
            NewAlbumView(albumToAddTo: currentAlbum)
        }
        .sheet(item: $albumToRename) {
            Task.detached(priority: .userInitiated) {
                await refreshAlbums()
            }
        } content: { album in
            RenameAlbumView(album: album)
        }
        .sheet(isPresented: $isImportingPhotos) {
            Task.detached(priority: .userInitiated) {
                await refreshIllustrations()
            }
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
        .task {
            styleState = style
            albumSortState = albumSort
        }
        .onAppear {
            Task.detached(priority: .background) {
                await refreshData()
            }
        }
        .onChange(of: styleState) { _, newValue in
            style = newValue
        }
        .onChange(of: albumSortState) { _, newValue in
            albumSort = newValue
        }
        .onChange(of: albumSort) { _, _ in
            Task.detached(priority: .userInitiated) {
                await refreshAlbums()
            }
        }
        .onChange(of: isIllustrationSortReversed) { _, _ in
            Task.detached(priority: .userInitiated) {
                await refreshIllustrations()
            }
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
