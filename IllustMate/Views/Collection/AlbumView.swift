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

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase

    var namespace: Namespace.ID

    var currentAlbum: Album?
    @State var albums: [Album]?
    @State var isConfirmingDeleteAlbum: Bool = false
    @State var albumPendingDeletion: Album?
    @State var isAddingAlbum: Bool = false
    @State var albumToRename: Album?
    @AppStorage(wrappedValue: SortType.nameAscending, "AlbumSort", store: defaults) var albumSort: SortType
    @State var albumSortState: SortType = .nameAscending
    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle", store: defaults) var albumStyle: ViewStyle
    @State var albumStyleState: ViewStyle = .grid

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

    @AppStorage(wrappedValue: false, "DebugButterItUp") var butterItUp: Bool

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
                            .tag(SortType.sizeAscending)
                        Label("Shared.Sort.IllustrationCount.Descending", image: "Sort.Count.Descending")
                            .tag(SortType.sizeDescending)
                    }
                    Picker("Albums.Style",
                           selection: (butterItUp ? $albumStyleState.animation(.snappy.speed(2)) :
                                        $albumStyleState)) {
                        Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                            .tag(ViewStyle.grid)
                        Label("Albums.Style.List", systemImage: "list.bullet")
                            .tag(ViewStyle.list)
                    }
                }
                .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
                if let albums {
                    if !albums.isEmpty {
                        Divider()
                            .padding([.leading], colorScheme == .light ? 0.0 : 20.0)
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
                        if colorScheme == .light || albumStyleState == .list {
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
            if albums != nil && illustrations != nil {
                Task {
                    await refreshData()
                }
            } else {
                albumStyleState = albumStyle
                albumSortState = albumSort
                Task.detached(priority: .userInitiated) {
                    await refreshData()
                }
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
