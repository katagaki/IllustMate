//
//  PhotosFolderView.swift
//  PicMate
//
//  Created on 2026/02/26.
//

import Photos
import SwiftUI

struct PhotosFolderView: View {

    @Environment(PhotosManager.self) var photosManager

    let folder: PHCollectionList

    @AppStorage("PhotosNestedAlbumsEnabled",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var isNestedAlbumsEnabled: Bool = false

    @Namespace var namespace

    @State private var items: [PHCollectionItem] = []
    @State private var ownPicsFetchResult: PHFetchResult<PHAsset>?
    @State private var hasFetched: Bool = false

    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumStyleState: ViewStyle
    @AppStorage(wrappedValue: 3, "AlbumColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumColumnCount: Int
    @AppStorage(wrappedValue: 4, "PicColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var picColumnCount: Int

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
                if !items.isEmpty {
                    albumsSection
                    Spacer()
                        .frame(height: 20.0)
                }

                if isNestedAlbumsEnabled, let fetchResult = ownPicsFetchResult, fetchResult.count > 0 {
                    picsSection(fetchResult: fetchResult)
                }
            }
            .padding([.top], 20.0)
        }
        .navigationTitle(folder.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
        .onAppear {
            if !hasFetched {
                fetchContent()
            }
        }
    }

    // MARK: - Sections

    private var albumsSection: some View {
        Group {
            SectionHeader(title: "Albums.Albums", count: items.count) {
                Picker("Albums.Style",
                       selection: $albumStyleState.animation(.smooth.speed(2))) {
                    Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                        .tag(ViewStyle.grid)
                    Label("Albums.Style.List", systemImage: "list.bullet")
                        .tag(ViewStyle.list)
                    Label("Albums.Style.Carousel", systemImage: "rectangle.on.rectangle")
                        .tag(ViewStyle.carousel)
                }
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
            }
            .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
            PhotosAlbumsSection(items: items, style: $albumStyleState)
        }
    }

    private func picsSection(fetchResult: PHFetchResult<PHAsset>) -> some View {
        Group {
            SectionHeader(title: "Albums.Pics", count: fetchResult.count) {
                Picker("Shared.GridSize",
                       systemImage: "square.grid.2x2",
                       selection: $picColumnCount.animation(.smooth.speed(2.0))) {
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
            }
            .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
            PhotosFetchResultAssetsGrid(namespace: namespace, fetchResult: fetchResult)
        }
    }

    // MARK: - Data

    private func fetchContent() {
        if isNestedAlbumsEnabled {
            let resolved = photosManager.resolveNestedAlbums(in: folder)

            var collected: [PHCollectionItem] = []
            for album in resolved.albums {
                collected.append(.album(album))
            }
            for subfolder in resolved.folders {
                collected.append(.folder(subfolder))
            }
            items = collected

            if let ownPicsCollection = resolved.ownPicsCollection {
                ownPicsFetchResult = photosManager.fetchAssets(in: ownPicsCollection)
            }
        } else {
            items = photosManager.fetchCollections(in: folder)
        }
        hasFetched = true
    }
}
