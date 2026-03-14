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

    @State var currentAlbum: Album?
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
    @State var picCount: Int = 0
    @State var hasFetchedPicCount: Bool = false
    @State var hasFetchedPics: Bool = false
    @State var isConfirmingDeletePic: Bool = false
    @State var isConfirmingDeleteSelectedPics: Bool = false
    @State var picPendingDeletion: Pic?
    @State var isSelectingPics: Bool = false
    @State var selectedPics: [Pic] = []
    @State var isImportingPhotos: Bool = false
    @AppStorage(wrappedValue: false, "PicSortReversed") var isPicSortReversed: Bool
    @AppStorage(wrappedValue: 4, "PicColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var columnCount: Int
    @AppStorage(wrappedValue: 3, "AlbumColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumColumnCount: Int

    @State var searchText: String = ""
    @State var searchResults: [Album]?
    @State var isDuplicateCheckerPresented: Bool = false

    var displayedAlbums: [Album] {
        searchResults ?? albums
    }

    var body: some View {
        mainContent
            .toolbar { toolbarContent }
            .modifier(AlbumViewSheets(
                isAddingAlbum: $isAddingAlbum,
                albumToRename: $albumToRename,
                isImportingPhotos: $isImportingPhotos,
                currentAlbum: currentAlbum,
                onAlbumDismiss: { refreshAlbumsAndSet() },
                onImportDismiss: { refreshPicsAndSet() }
            ))
            .sheet(isPresented: $isDuplicateCheckerPresented) {
                Group {
                    if let currentAlbum {
                        DuplicateScanView(scanScope: .album(currentAlbum))
                    } else {
                        DuplicateScanView(scanScope: .picsNotInAlbums)
                    }
                }
                .phonePresentationDetents([.medium, .large])
                .interactiveDismissDisabled()
            }
            .modifier(AlbumViewDialogs(
                isConfirmingDeleteAlbum: $isConfirmingDeleteAlbum,
                isConfirmingDeletePic: $isConfirmingDeletePic,
                isConfirmingDeleteSelectedPics: $isConfirmingDeleteSelectedPics,
                albumPendingDeletion: $albumPendingDeletion,
                picPendingDeletion: $picPendingDeletion,
                selectedPicsCount: selectedPics.count,
                onConfirmDeleteAlbum: { confirmDeleteAlbum() },
                onConfirmDeletePic: { confirmDeletePic() }
            ))
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
            .onChange(of: navigation.dataVersion) { _, _ in
                Task.detached(priority: .userInitiated) {
                    await refreshData()
                }
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty {
                    searchResults = nil
                } else {
                    Task.detached(priority: .userInitiated) {
                        await searchAlbums(matching: newValue)
                    }
                }
            }
            .navigationTitle(currentAlbum?.name ?? String(localized: "ViewTitle.Collection"))
            .searchable(text: $searchText, prompt: "Albums.Search.Prompt")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
                Text("Shared.Selected.\(selectedPics.count)")
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Menu("Shared.Move", systemImage: "tray.full") {
                    PicMoveMenu(pics: selectedPics, containingAlbum: currentAlbum) {
                        refreshDataAfterPicMoved()
                    }
                }
                .disabled(selectedPics.isEmpty)
                Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                    deletePics()
                }
                .disabled(selectedPics.isEmpty)
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    selectOrDeselectAllPics()
                } label: {
                    if pics.count == selectedPics.count {
                        Label("Shared.DeselectAll", systemImage: "rectangle.stack")
                    } else {
                        Label("Shared.SelectAll", systemImage: "checkmark.rectangle.stack")
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
                Button("Shared.Create", systemImage: "rectangle.stack.badge.plus") {
                    isAddingAlbum = true
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
    private var filterMenu: some View {
        Menu {
            Button("Shared.Import", systemImage: "square.and.arrow.down.on.square") {
                isImportingPhotos = true
            }
            Button("Duplicates.FindDuplicates", systemImage: "photo.stack") {
                isDuplicateCheckerPresented = true
            }
            Divider()
            Section("Albums.Albums") {
                Picker("Albums.Style",
                       systemImage: "paintbrush",
                       selection: ($albumStyleState.animation(.smooth.speed(2)))) {
                    Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                        .tag(ViewStyle.grid)
                    Label("Albums.Style.List", systemImage: "list.bullet")
                        .tag(ViewStyle.list)
                    Label("Albums.Style.Carousel", systemImage: "rectangle.on.rectangle")
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
            Section("Albums.Pics") {
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
                Picker("Shared.Sort", systemImage: "arrow.up.arrow.down", selection: $isPicSortReversed) {
                    Text("Shared.Sort.DateAdded.Ascending")
                        .tag(true)
                    Text("Shared.Sort.DateAdded.Descending")
                        .tag(false)
                }
                .pickerStyle(.menu)
            }
        } label: {
            Label("Shared.Filter", systemImage: "line.3.horizontal.decrease")
        }
        .menuActionDismissBehavior(.disabled)
    }

    private var mainContent: some View {
        ZStack {
            if let currentAlbum, let coverPhoto = currentAlbum.coverPhoto, let uiImage = UIImage(data: coverPhoto) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .blur(radius: 20.0)
                    .opacity(0.25)
                    .transition(.opacity.animation(.smooth))
            }

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0.0) {
                    if !isSelectingPics {
                        albumSection
                        if !searchText.isEmpty {
                            if displayedAlbums.isEmpty {
                                Text("Albums.NoSearchResults")
                                    .foregroundStyle(.secondary)
                                    .padding(20.0)
                            }
                        } else {
                            Spacer()
                                .frame(height: 20.0)
                        }
                    }
                    if searchText.isEmpty {
                        picsSection
                    }
                }
                .padding([.top], 20.0)
            }
        }
    }

}

private struct AlbumViewSheets: ViewModifier {
    @Binding var isAddingAlbum: Bool
    @Binding var albumToRename: Album?
    @Binding var isImportingPhotos: Bool
    let currentAlbum: Album?
    let onAlbumDismiss: () -> Void
    let onImportDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isAddingAlbum) {
                onAlbumDismiss()
            } content: {
                NewAlbumView(albumToAddTo: currentAlbum)
            }
            .sheet(item: $albumToRename) {
                onAlbumDismiss()
            } content: { album in
                RenameAlbumView(album: album)
            }
            .sheet(isPresented: $isImportingPhotos) {
                onImportDismiss()
            } content: {
                ImporterView(selectedAlbum: currentAlbum)
            }
    }
}

private struct AlbumViewDialogs: ViewModifier {
    @Binding var isConfirmingDeleteAlbum: Bool
    @Binding var isConfirmingDeletePic: Bool
    @Binding var isConfirmingDeleteSelectedPics: Bool
    @Binding var albumPendingDeletion: Album?
    @Binding var picPendingDeletion: Pic?
    let selectedPicsCount: Int
    let onConfirmDeleteAlbum: () -> Void
    let onConfirmDeletePic: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                Text("Shared.DeleteConfirmation.Album.\(albumPendingDeletion?.name ?? "")"),
                isPresented: $isConfirmingDeleteAlbum
            ) {
                Button("Shared.Yes", role: .destructive) {
                    onConfirmDeleteAlbum()
                }
                Button("Shared.No", role: .cancel) {
                    albumPendingDeletion = nil
                }
            } message: {
                Text("Shared.DeleteConfirmation.Album.Message")
            }
            .alert("Shared.DeleteConfirmation.Pic",
                   isPresented: $isConfirmingDeletePic) {
                Button("Shared.Yes", role: .destructive) {
                    onConfirmDeletePic()
                }
                Button("Shared.No", role: .cancel) {
                    picPendingDeletion = nil
                }
            }
            .alert("Shared.DeleteConfirmation.Pic.\(selectedPicsCount)",
                   isPresented: $isConfirmingDeleteSelectedPics) {
                Button("Shared.Yes", role: .destructive) {
                    onConfirmDeletePic()
                }
                Button("Shared.No", role: .cancel) {
                    picPendingDeletion = nil
                }
            }
    }
}
