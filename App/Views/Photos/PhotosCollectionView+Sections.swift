//
//  PhotosCollectionView+Sections.swift
//  PicMate
//
//  Created on 2026/02/26.
//

import Photos
import SwiftUI

// MARK: - Sections

extension PhotosCollectionView {
    var collectionContent: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
                photosAlbumsSection
                if searchText.isEmpty {
                    Spacer()
                        .frame(height: 20.0)
                    photosPicsSection
                }
            }
            .padding([.top], 20.0)
        }
        .onAppear {
            if !hasFetchedCollections {
                items = photosManager.fetchTopLevelCollections()
                hasFetchedCollections = true
            }
        }
        .task {
            if !hasFetchedRootAssets && !isFetchingRootAssets {
                isFetchingRootAssets = true
                rootAssets = await photosManager.fetchAssetsNotInAnyAlbum()
                hasFetchedRootAssets = true
                isFetchingRootAssets = false
            }
        }
    }

    var photosAlbumsSection: some View {
        Group {
            Group {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    SectionHeader(title: "Albums.Albums", count: filteredItems.count)
                } else {
                    SectionHeader(title: "Albums.Albums", count: filteredItems.count) {
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
                }
            }
            .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
            if !filteredItems.isEmpty {
                PhotosAlbumsSection(items: filteredItems, style: $albumStyleState,
                                    onRename: { collection in
                                        albumToRename = collection
                                    },
                                    onDelete: { collection in
                                        albumToDelete = collection
                                        isConfirmingDeleteAlbum = true
                                    },
                                    onMoveToFolder: { collection in
                                        albumToMove = collection
                                    },
                                    onDeleteFolder: { folder in
                                        folderToDelete = folder
                                        isConfirmingDeleteFolder = true
                                    },
                                    onDropAssets: { transferable, collection in
                                        addDroppedAsset(transferable, to: collection)
                                    },
                                    coverRefreshID: coverRefreshID)
            } else if hasFetchedCollections {
                if searchText.isEmpty {
                    Text("Albums.NoAlbums")
                        .foregroundStyle(.secondary)
                        .padding(20.0)
                }
            }
        }
    }

    var photosPicsSection: some View {
        Group {
            if !hasFetchedRootAssets {
                SectionHeader(title: "Albums.Pics", count: 0)
                    .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(20.0)
            } else if !rootAssets.isEmpty {
                Group {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        SectionHeader(title: "Albums.Pics", count: rootAssets.count)
                    } else {
                        SectionHeader(title: "Albums.Pics", count: rootAssets.count) {
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
                    }
                }
                .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
                PhotosAssetsGrid(namespace: namespace, assets: rootAssets)
            }
        }
    }

    // MARK: - Access Denied

    var photosAccessDeniedView: some View {
        VStack(spacing: 16.0) {
            Image(systemName: "photo.badge.exclamationmark")
                .resizable()
                .scaledToFit()
                .frame(width: 64.0, height: 64.0)
                .foregroundStyle(.secondary)
            Text("Import.PhotosAccessDenied")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Import.OpenSettings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(40.0)
    }
}
