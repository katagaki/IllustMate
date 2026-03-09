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
            .safeAreaInset(edge: .bottom) {
                if isSelectingPics {
                    selectionBarContent
                }
            }
            .modifier(AlbumViewSheets(
                isAddingAlbum: $isAddingAlbum,
                albumToRename: $albumToRename,
                isImportingPhotos: $isImportingPhotos,
                currentAlbum: currentAlbum,
                onAlbumDismiss: { refreshAlbumsAndSet() },
                onImportDismiss: { refreshPicsAndSet() }
            ))
            .sheet(isPresented: $isDuplicateCheckerPresented) {
                DuplicateScanView(preselectedAlbum: currentAlbum)
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

    private var mainContent: some View {
        ZStack {
            if let currentAlbum, let coverPhoto = currentAlbum.coverPhoto, let uiImage = UIImage(data: coverPhoto) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .blur(radius: 20.0)
                    .overlay {
                        Group {
                            if colorScheme == .light {
                                Color.white.opacity(0.9)
                            } else {
                                Color.black.opacity(0.8)
                            }
                        }
                        .ignoresSafeArea()
                    }
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

    private var selectionBarContent: some View {
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
            .confirmationDialog("Shared.DeleteConfirmation.Pic",
                                isPresented: $isConfirmingDeletePic, titleVisibility: .visible) {
                Button("Shared.Yes", role: .destructive) {
                    onConfirmDeletePic()
                }
                Button("Shared.No", role: .cancel) {
                    picPendingDeletion = nil
                }
            }
            .confirmationDialog("Shared.DeleteConfirmation.Pic.\(selectedPicsCount)",
                                isPresented: $isConfirmingDeleteSelectedPics, titleVisibility: .visible) {
                Button("Shared.Yes", role: .destructive) {
                    onConfirmDeletePic()
                }
                Button("Shared.No", role: .cancel) {
                    picPendingDeletion = nil
                }
            }
    }
}
