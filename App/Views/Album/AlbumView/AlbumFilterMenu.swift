//
//  AlbumFilterMenu.swift
//  PicMate
//
//  Created by Claude on 2026/03/23.
//

import SwiftUI

struct AlbumFilterMenu: View {

    @Binding var isDuplicateCheckerPresented: Bool
    @Binding var albumStyleState: ViewStyle
    @Binding var albumColumnCount: Int
    @Binding var albumSortState: SortType
    @Binding var columnCount: Int
    @Binding var picSortType: PicSortType
    @Binding var hideSectionHeaders: Bool

    var body: some View {
        Menu {
            Button(String(localized: "Duplicates.FindDuplicates", table: "Photos"),
                   systemImage: "photo.stack") {
                isDuplicateCheckerPresented = true
            }
            Section(String(localized: "Albums.Albums", table: "Albums")) {
                Picker(String(localized: "Albums.Style", table: "Albums"),
                       systemImage: "paintbrush",
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
            }
            Section(String(localized: "Albums.Pics", table: "Albums")) {
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
            }
            Section {
                Toggle(String(localized: "Albums.HideHeaders", table: "Albums"),
                       isOn: $hideSectionHeaders)
            }
        } label: {
            Label("Shared.Filter", systemImage: "line.3.horizontal.decrease")
        }
        .menuActionDismissBehavior(.disabled)
        .menuOrder(.fixed)
    }
}
