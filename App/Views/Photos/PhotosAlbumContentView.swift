//
//  PhotosAlbumContentView.swift
//  PicMate
//
//  Created on 2026/02/26.
//

import Photos
import SwiftUI

struct PhotosAlbumContentView: View {

    @Environment(PhotosManager.self) var photosManager

    let collection: PHAssetCollection

    @Namespace var namespace

    @State private var fetchResult: PHFetchResult<PHAsset>?
    @State private var hasFetched: Bool = false

    @AppStorage(wrappedValue: 4, "PicColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var columnCount: Int

    @State private var isDuplicateCheckerPresented: Bool = false

    private var assetCount: Int {
        fetchResult?.count ?? 0
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
                Group {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        SectionHeader(title: String(localized: "Albums.Pics", table: "Albums"),
                                      count: assetCount)
                    } else {
                        SectionHeader(title: String(localized: "Albums.Pics", table: "Albums"),
                                      count: assetCount) {
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
                        }
                    }
                }
                .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))

                if !hasFetched {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(20.0)
                } else if let fetchResult, fetchResult.count > 0 {
                    PhotosFetchResultAssetsGrid(namespace: namespace, fetchResult: fetchResult)
                } else {
                    Text("Albums.NoPics", tableName: "Albums")
                        .foregroundStyle(.secondary)
                        .padding(20.0)
                }
            }
            .padding([.top], 20.0)
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle(collection.localizedTitle ?? String(localized: "Import.Albums.Untitled", table: "Import"))
        .toolbar {
            if UIDevice.current.userInterfaceIdiom == .phone {
                ToolbarItemGroup(placement: .bottomBar) {
                    photosFilterMenu
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
            }
        }
        .sheet(isPresented: $isDuplicateCheckerPresented) {
            PhotosDuplicateScanView(collection: collection)
                .phonePresentationDetents([.medium, .large])
                .interactiveDismissDisabled()
        }
        .onChange(of: isDuplicateCheckerPresented) { _, isPresented in
            if !isPresented {
                fetchResult = photosManager.fetchAssets(in: collection)
            }
        }
        .onAppear {
            if !hasFetched {
                fetchResult = photosManager.fetchAssets(in: collection)
                hasFetched = true
            }
        }
    }

    @ViewBuilder
    private var photosFilterMenu: some View {
        Menu {
            Button(String(localized: "Duplicates.FindDuplicates", table: "Photos"), systemImage: "photo.stack") {
                isDuplicateCheckerPresented = true
            }
            Section(String(localized: "Albums.Pics", table: "Albums")) {
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
            }
        } label: {
            Label("Shared.Filter", systemImage: "line.3.horizontal.decrease")
        }
        .menuActionDismissBehavior(.disabled)
    }
}
