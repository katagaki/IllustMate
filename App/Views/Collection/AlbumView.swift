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
    @EnvironmentObject var libraryManager: LibraryManager
    @Environment(ViewerManager.self) var viewer

    @Namespace var namespace

    @State var currentAlbum: Album?
    @State var albums: [Album] = []
    @State var hasFetchedAlbums: Bool = false
    @State var isConfirmingDeleteAlbum: Bool = false
    @State var albumPendingDeletion: Album?
    @State var isAddingAlbum: Bool = false
    @State var newAlbumName: String = ""
    @State var albumToRename: Album?
    @State var renameAlbumText: String = ""
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
    @State var isBrowsingFolders: Bool = false
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
    @AppStorage(wrappedValue: false, "HideSectionHeaders",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var hideSectionHeaders: Bool

    @State var backgroundImage: UIImage?
    @State var lastRefreshTime: Date = .distantPast
    @State var searchText: String = ""
    @State var searchResults: [Album]?
    @State var searchTask: Task<Void, Never>?
    @State var isDuplicateCheckerPresented: Bool = false

    var displayedAlbums: [Album] {
        searchResults ?? albums
    }

    var navigationTitleText: String {
        currentAlbum?.name ?? libraryManager.displayName(for: libraryManager.currentLibrary)
    }

    var navigationSubtitleText: String {
        if currentAlbum != nil && !libraryManager.currentLibrary.isDefault {
            return libraryManager.currentLibrary.name
        }
        return ""
    }

    var body: some View {
        mainContent
            .toolbar { toolbarContent }
            .modifier(AlbumViewSheets(
                isAddingAlbum: $isAddingAlbum,
                newAlbumName: $newAlbumName,
                albumToRename: $albumToRename,
                renameAlbumText: $renameAlbumText,
                isBrowsingAlbums: $isBrowsingAlbums,
                isBrowsingFolders: $isBrowsingFolders,
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
            .task(id: currentAlbum.map { "\($0.id)-\($0.hasCoverPhoto)-\($0.coverPhoto != nil)" }) {
                await updateBackgroundImage()
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
                    let now = Date.now
                    guard now.timeIntervalSince(lastRefreshTime) > 5.0 else { return }
                    lastRefreshTime = now
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
                searchTask?.cancel()
                if newValue.isEmpty {
                    searchResults = nil
                } else {
                    searchTask = Task.detached(priority: .userInitiated) {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        await searchAlbums(matching: newValue)
                    }
                }
            }
            .navigationTitle(navigationTitleText)
            .navigationSubtitle(Text(verbatim: navigationSubtitleText))
            .searchable(text: $searchText, prompt: Text("Albums.Search.Prompt", tableName: "Albums"))
    }

    var mainContent: some View {
        ZStack {
            // Album cover background image (if set)
            if let backgroundImage {
                Canvas { context, size in
                    let image = context.resolve(Image(uiImage: backgroundImage))
                    let imageSize = image.size
                    let scale = max(size.width / imageSize.width,
                                    size.height / imageSize.height)
                    let drawSize = CGSize(width: imageSize.width * scale,
                                          height: imageSize.height * scale)
                    let origin = CGPoint(x: (size.width - drawSize.width) / 2,
                                         y: (size.height - drawSize.height) / 2)
                    context.opacity = 0.25
                    context.draw(image, in: CGRect(origin: origin, size: drawSize))
                }
                .ignoresSafeArea()
                .transition(.opacity.animation(.smooth.speed(2.0)))
            }

            if hideSectionHeaders && searchText.isEmpty
                && hasFetchedAlbums && displayedAlbums.isEmpty
                && hasFetchedPicCount && picCount == 0 {
                ContentUnavailableView(
                    String(localized: "Albums.Empty", table: "Albums"),
                    systemImage: "photo.on.rectangle.angled"
                )
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0.0) {
                        if !isSelectingPics {
                            VStack(alignment: .leading, spacing: 0.0) {
                                albumSection
                                if !searchText.isEmpty {
                                    if displayedAlbums.isEmpty {
                                        Text("Albums.NoSearchResults", tableName: "Albums")
                                            .foregroundStyle(.secondary)
                                            .padding(20.0)
                                    }
                                } else if !hideSectionHeaders || !displayedAlbums.isEmpty {
                                    Spacer()
                                        .frame(height: 20.0)
                                }
                            }
                            .transition(.opacity.animation(.smooth.speed(2.0)))
                        }
                        if searchText.isEmpty {
                            picsSection
                        }
                    }
                    .padding(.top, (hideSectionHeaders && displayedAlbums.isEmpty) ? 0.0 : 20.0)
                    .animation(.smooth.speed(2.0), value: hideSectionHeaders)
                }
            }
        }
    }
}
