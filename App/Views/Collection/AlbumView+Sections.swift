//
//  AlbumView+Sections.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/02/24.
//

import SwiftUI

extension AlbumView {
    var albumSection: some View {
        Group {
            Group {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    SectionHeader(title: "Albums.Albums", count: displayedAlbums.count)
                } else {
                    SectionHeader(title: "Albums.Albums", count: displayedAlbums.count) {
                        Picker("Albums.Style", selection: ($albumStyleState.animation(.smooth.speed(2)))) {
                            Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                                .tag(ViewStyle.grid)
                            Label("Albums.Style.List", systemImage: "list.bullet")
                                .tag(ViewStyle.list)
                            Label("Albums.Style.Carousel", systemImage: "rectangle.on.rectangle")
                                .tag(ViewStyle.carousel)
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
            if !displayedAlbums.isEmpty {
                AlbumsSection(albums: displayedAlbums, style: $albumStyleState) { album in
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
            } else if searchText.isEmpty {
                Text("Albums.NoAlbums")
                    .foregroundStyle(.secondary)
                    .padding(20.0)
            }
        }
    }

    var picsSection: some View {
        Group {
            Group {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    SectionHeader(title: "Albums.Pics", count: hasFetchedPicCount ? picCount : pics.count)
                } else {
                    SectionHeader(title: "Albums.Pics", count: hasFetchedPicCount ? picCount : pics.count) {
                        Button("Shared.Import", systemImage: "square.and.arrow.down.on.square") {
                            isImportingPhotos = true
                        }
                        Button("Duplicates.FindDuplicates", systemImage: "photo.stack") {
                            isDuplicateCheckerPresented = true
                        }
                        Divider()
                        Picker("Shared.Sort", systemImage: "arrow.up.arrow.down", selection: $isPicSortReversed) {
                            Text("Shared.Sort.DateAdded.Ascending")
                                .tag(true)
                            Text("Shared.Sort.DateAdded.Descending")
                                .tag(false)
                        }
                        .pickerStyle(.menu)
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
            .disabled(isSelectingPics)
            .padding(EdgeInsets(top: 0.0,
                                leading: 20.0,
                                bottom: 6.0,
                                trailing: 20.0))
            if hasFetchedPicCount && picCount > 0 {
                PicsGrid(namespace: namespace, pics: pics,
                         placeholderCount: max(picCount - pics.count, 0),
                         isSelecting: $isSelectingPics) { pic in
                    selectedPics.contains(pic)
                } onSelect: { pic in
                    selectOrDeselectPic(pic)
                } selectedCount: {
                    selectedPics.count
                } onDelete: { pic in
                    deletePic(pic)
                } moveMenu: { pic in
                    PicMoveMenu(pics: isSelectingPics ?
                                selectedPics : [pic],
                                containingAlbum: currentAlbum) {
                        refreshDataAfterPicMoved()
                    }
                }
            } else if !hasFetchedPicCount {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(20.0)
            } else if picCount == 0 {
                Text("Albums.NoPics")
                    .foregroundStyle(.secondary)
                    .padding(20.0)
            }
        }
    }
}
