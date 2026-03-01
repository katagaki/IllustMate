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

    var body: some View {
        ZStack {
            // Background image
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
                                Color.white.opacity(0.2)
                            } else {
                                Color.black.opacity(0.7)
                            }
                        }
                        .ignoresSafeArea()
                    }
                    .transition(.opacity.animation(.smooth))
            }

            // Main scroll view
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0.0) {
                    if !isSelectingPics {
                        albumSection
                        Spacer()
                            .frame(height: 20.0)
                    }
                    picsSection
                }
                .padding([.top], 20.0)
            }
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
        .confirmationDialog("Shared.DeleteConfirmation.Pic",
                            isPresented: $isConfirmingDeletePic, titleVisibility: .visible) {
            Button("Shared.Yes", role: .destructive) {
                confirmDeletePic()
            }
            Button("Shared.No", role: .cancel) {
                picPendingDeletion = nil
            }
        }
        .confirmationDialog("Shared.DeleteConfirmation.Pic.\(selectedPics.count)",
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
        .onChange(of: navigation.dataVersion) { _, _ in
            Task.detached(priority: .userInitiated) {
                await refreshData()
            }
        }
        .navigationTitle(currentAlbum?.name ?? String(localized: "ViewTitle.Collection"))
    }
}
