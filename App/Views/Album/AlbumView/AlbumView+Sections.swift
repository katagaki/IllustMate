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
            if !hideSectionHeaders {
                Group {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        SectionHeader(title: String(localized: "Albums.Albums", table: "Albums"),
                                      count: displayedAlbums.count)
                    } else {
                        SectionHeader(title: String(localized: "Albums.Albums", table: "Albums"),
                                      count: displayedAlbums.count) {
                            Picker(String(localized: "Albums.Style", table: "Albums"),
                                   selection: ($albumStyleState.animation(.smooth.speed(2.0)))) {
                                Label(String(localized: "Albums.Style.Grid", table: "Albums"),
                                      systemImage: "square.grid.2x2")
                                    .tag(ViewStyle.grid)
                                Label(String(localized: "Albums.Style.List", table: "Albums"),
                                      systemImage: "list.bullet")
                                    .tag(ViewStyle.list)
                                Label(String(localized: "Albums.Style.Carousel", table: "Albums"),
                                      systemImage: "rectangle.on.rectangle")
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
                                    Text("Shared.GridSize.5")
                                        .tag(5)
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                }
                .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if !displayedAlbums.isEmpty {
                AlbumsSection(albums: displayedAlbums, style: $albumStyleState,
                             columnCount: albumColumnCount,
                             hideSectionHeaders: hideSectionHeaders) { album in
                    renameAlbumText = album.name
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
            } else if searchText.isEmpty && !hideSectionHeaders {
                Text("Albums.NoAlbums", tableName: "Albums")
                    .foregroundStyle(.secondary)
                    .padding(20.0)
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var picsSection: some View {
        Group {
            if !hideSectionHeaders {
                Group {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        SectionHeader(title: String(localized: "Albums.Pics", table: "Albums"),
                                      count: hasFetchedPicCount ? picCount : pics.count)
                    } else {
                        SectionHeader(title: String(localized: "Albums.Pics", table: "Albums"),
                                      count: hasFetchedPicCount ? picCount : pics.count) {
                            Button(
                                String(localized: "Duplicates.FindDuplicates", table: "Photos"),
                                systemImage: "photo.stack"
                            ) {
                                isDuplicateCheckerPresented = true
                            }
                            Divider()
                            Picker("Shared.Sort", systemImage: "arrow.up.arrow.down", selection: $picSortType) {
                                Text("Shared.Sort.DateAdded.Ascending")
                                    .tag(PicSortType.dateAddedAscending)
                                Text("Shared.Sort.DateAdded.Descending")
                                    .tag(PicSortType.dateAddedDescending)
                                Text("Shared.Sort.Name.Ascending")
                                    .tag(PicSortType.nameAscending)
                                Text("Shared.Sort.Name.Descending")
                                    .tag(PicSortType.nameDescending)
                                Text("Shared.Sort.ProminentColor")
                                    .tag(PicSortType.prominentColor)
                            }
                            .pickerStyle(.menu)
                            Picker("Shared.GridSize",
                                   systemImage: "square.grid.2x2",
                                   selection: $columnCount.animation(.smooth.speed(2.0))) {
                                Text("Shared.GridSize.2")
                                    .tag(2)
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
                .opacity(isSelectingPics ? 0.5 : 1.0)
                .animation(.smooth.speed(2.0), value: isSelectingPics)
                .padding(EdgeInsets(top: 0.0,
                                    leading: 20.0,
                                    bottom: 6.0,
                                    trailing: 20.0))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if hasFetchedPicCount && picCount > 0 {
                PicsGrid(namespace: namespace, pics: pics,
                         placeholderCount: max(picCount - pics.count, 0),
                         isSelecting: $isSelectingPics,
                         columnCount: columnCount) { pic in
                    selectedPics.contains(pic)
                } onSelect: { pic in
                    selectOrDeselectPic(pic)
                } selectedCount: {
                    selectedPics.count
                } onDelete: { pic in
                    deletePic(pic)
                } moveMenu: { pic in
                    Menu("Shared.MoveTo", systemImage: "tray.and.arrow.down") {
                        PicMoveMenu(pics: isSelectingPics ?
                                    selectedPics : [pic],
                                    containingAlbum: currentAlbum) {
                            refreshDataAfterPicMoved()
                        }
                    }
                }
            } else if !hasFetchedPicCount {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(20.0)
            } else if picCount == 0 && !hideSectionHeaders {
                Text("Albums.NoPics", tableName: "Albums")
                    .foregroundStyle(.secondary)
                    .padding(20.0)
            }
        }
    }
}
