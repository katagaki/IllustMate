//
//  AlbumView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

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
    @State var isBrowsingAlbums: Bool = false
    @State var isFileImporterPresented: Bool = false
    @State var isPhotosPickerPresented: Bool = false
    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State var isImportingPhotos: Bool = false
    @State var importCurrentCount: Int = 0
    @State var importTotalCount: Int = 0
    @State var importCompletedCount: Int = 0
    @State var isImportCompleted: Bool = false
    @AppStorage(wrappedValue: PicSortType.dateAddedDescending, "PicSortType",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var picSortType: PicSortType
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
                isBrowsingAlbums: $isBrowsingAlbums,
                isImportingPhotos: $isImportingPhotos,
                isImportCompleted: $isImportCompleted,
                importCurrentCount: importCurrentCount,
                importTotalCount: importTotalCount,
                importCompletedCount: importCompletedCount,
                currentAlbum: currentAlbum,
                onAlbumDismiss: { refreshAlbumsAndSet() },
                onBrowseAlbumsDismiss: { refreshPicsAndSet() },
                onImportDismiss: {
                    isImportCompleted = false
                    importCurrentCount = 0
                    importTotalCount = 0
                    importCompletedCount = 0
                    refreshPicsAndSet()
                }
            ))
            .photosPicker(isPresented: $isPhotosPickerPresented,
                          selection: $selectedPhotoItems,
                          matching: .images,
                          photoLibrary: .shared())
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    importFiles(urls)
                case .failure:
                    break
                }
            }
            .onChange(of: selectedPhotoItems) { _, newValue in
                if !newValue.isEmpty {
                    importSelectedPhotos(newValue)
                }
            }
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
            .onChange(of: isDuplicateCheckerPresented) { _, isPresented in
                if !isPresented {
                    refreshPicsAndSet()
                }
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
            .onChange(of: picSortType) { _, _ in
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

    var mainContent: some View {
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
