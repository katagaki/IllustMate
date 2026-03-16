//
//  AlbumsView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/18.
//

import SwiftUI

struct AlbumsView: View {

    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var navigation: NavigationManager
    @Environment(ViewerManager.self) var viewer

    @Namespace var namespace

    @State var albums: [Album] = []
    @State private var lastDataVersion: Int = -1
    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var style: ViewStyle

    @State var viewerManager = ViewerManager()

    var body: some View {
        ZStack {
            NavigationStack(path: $navigation.albumsTabPath) {
                ScrollView(.vertical) {
                    AlbumsSection(albums: albums, style: $style) { _ in
                        // TODO: Move menu support in macOS Albums view
                    }
                }
                .toolbar {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        ToolbarItem(placement: .topBarTrailing) {
                            HStack(alignment: .center, spacing: 8.0) {
                                Text("\(albums.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("ViewTitle.Albums")
            }
        }
        .onAppear {
            refreshAlbumsIfNeeded()
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                refreshAlbumsIfNeeded()
            }
        }
        .onChange(of: navigation.dataVersion) { _, _ in
            refreshAlbumsIfNeeded()
        }
    }

    func refreshAlbumsIfNeeded() {
        let currentVersion = navigation.dataVersion
        guard currentVersion != lastDataVersion || albums.isEmpty else { return }
        lastDataVersion = currentVersion
        Task.detached(priority: .userInitiated) {
            do {
                let albums = try await DataActor.shared.albumsWithCounts(sortedBy: .nameAscending)
                // Pre-warm cover cache for all albums in a single batch query
                await Self.prefetchAlbumCovers(for: albums)
                await MainActor.run {
                    doWithAnimation {
                        self.albums = albums
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }

    /// Batch-fetches and caches album cover thumbnails for albums not already in cache.
    private static func prefetchAlbumCovers(for albums: [Album]) async {
        let uncachedIDs = albums.compactMap { album -> String? in
            AlbumCoverCache.shared.images(forAlbumID: album.id) == nil ? album.id : nil
        }
        guard !uncachedIDs.isEmpty else { return }

        let albumsByID = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })
        let batchThumbnails = await DataActor.shared.batchRepresentativeThumbnails(
            forAlbumIDs: uncachedIDs
        )

        await withTaskGroup(of: Void.self) { group in
            for albumID in uncachedIDs {
                let album = albumsByID[albumID]
                let thumbnailDatas = batchThumbnails[albumID] ?? []
                group.addTask {
                    let hasCoverPhoto = album?.coverPhoto != nil
                    var images: [Image?] = []

                    if hasCoverPhoto, let coverData = album?.coverPhoto,
                       let uiImage = UIImage(data: coverData),
                       let prepared = await uiImage.byPreparingForDisplay() {
                        images.append(Image(uiImage: prepared))
                    }

                    for data in thumbnailDatas {
                        if let uiImage = UIImage(data: data),
                           let prepared = await uiImage.byPreparingForDisplay() {
                            images.append(Image(uiImage: prepared))
                        }
                    }
                    while images.count < 3 { images.append(nil) }

                    AlbumCoverCache.shared.setImages(
                        AlbumCoverCache.CoverImages(
                            primary: images[0],
                            secondary: images[1],
                            tertiary: images[2]
                        ),
                        forAlbumID: albumID
                    )
                }
            }
        }
    }
}
