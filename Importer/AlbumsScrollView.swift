//
//  AlbumsScrollView.swift
//  Importer
//
//  Created by シン・ジャスティン on 2023/10/15.
//

import Komponents
import SwiftUI

struct AlbumsScrollView: View {

    var title: LocalizedStringKey
    var parentAlbum: Album?
    @State var albums: [Album] = []
    @State var searchResults: [Album]?
    @State var isAlbumsLoaded: Bool = false
    @State var searchText: String = ""

    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var style: ViewStyle
    @AppStorage(wrappedValue: SortType.nameAscending, "AlbumSort",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumSort: SortType

    var displayedAlbums: [Album] {
        searchResults ?? albums
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
                Text(title)
                    .font(.title)
                    .bold()
                    .padding([.leading, .trailing], 20.0)
                    .padding([.top], 10.0)
                Divider()
                    .padding([.leading], 20.0)
                    .padding([.top], 10.0)

                if isAlbumsLoaded {
                    if displayedAlbums.isEmpty {
                        if searchResults != nil && !searchText.isEmpty {
                            Text("Albums.NoSearchResults")
                                .foregroundStyle(.secondary)
                                .padding([.leading, .trailing], 20.0)
                                .padding([.top], 10.0)
                        } else {
                            Text("Albums.NoMoreAlbums")
                                .foregroundStyle(.secondary)
                                .padding([.leading, .trailing], 20.0)
                                .padding([.top], 10.0)
                        }
                    } else {
                        AlbumsSection(albums: displayedAlbums, style: $style,
                                      enablesContextMenu: false) { _ in
                        }
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding([.leading, .trailing], 20.0)
                        .padding([.top], 10.0)
                }
            }
        }
        .onAppear {
            Task {
                do {
                    let albums = try await DataActor.shared.albumsWithCounts(
                        in: parentAlbum, sortedBy: albumSort
                    )
                    await MainActor.run {
                        self.albums = albums
                        isAlbumsLoaded = true
                    }
                } catch {
                    debugPrint(error.localizedDescription)
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                searchResults = nil
            } else {
                Task {
                    do {
                        let results = try await DataActor.shared.searchAlbums(
                            matching: newValue, in: parentAlbum, sortedBy: albumSort
                        )
                        await MainActor.run {
                            searchResults = results
                        }
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) {
                    close()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Albums.Search.Prompt")
    }

    func close() {
        NotificationCenter.default.post(name: NSNotification.Name("close"), object: nil)
    }
}
