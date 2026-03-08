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
    @State var searchResults: [Album] = []
    @State var isAlbumsLoaded: Bool = false
    @State var searchText: String = ""
    @State var isSearching: Bool = false
    @FocusState var isSearchFieldFocused: Bool

    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var style: ViewStyle
    @AppStorage(wrappedValue: SortType.nameAscending, "AlbumSort",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var albumSort: SortType

    static let searchHistoryKey = "ShareSheetSearchHistory"
    static let maxHistoryCount = 3

    var displayedAlbums: [Album] {
        isSearching && !searchText.isEmpty ? searchResults : albums
    }

    var body: some View {
        ZStack(alignment: .top) {
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

                    // Search bar
                    HStack(spacing: 8.0) {
                        HStack(spacing: 6.0) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            TextField("Albums.Search", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isSearchFieldFocused)
                                .submitLabel(.search)
                                .onSubmit {
                                    if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                                        saveSearchHistory(searchText.trimmingCharacters(in: .whitespaces))
                                        performSearch()
                                    }
                                }
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    if isSearching {
                                        searchResults = []
                                        isSearching = false
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding(8.0)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(.rect(cornerRadius: 10.0))

                        if isSearchFieldFocused || isSearching {
                            Button("Shared.Cancel") {
                                searchText = ""
                                searchResults = []
                                isSearching = false
                                isSearchFieldFocused = false
                            }
                            .font(.subheadline)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding([.leading, .trailing], 20.0)
                    .padding([.top], 10.0)
                    .animation(.smooth.speed(2), value: isSearchFieldFocused)
                    .animation(.smooth.speed(2), value: isSearching)

                    if isAlbumsLoaded {
                        if displayedAlbums.isEmpty {
                            if isSearching && !searchText.isEmpty {
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
                                // Move menu not supported when in importer extension
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

            // Search history overlay
            if isSearchFieldFocused && searchText.isEmpty && !isSearching {
                let history = searchHistory()
                if !history.isEmpty {
                    VStack(spacing: 0.0) {
                        Spacer()
                            .frame(height: searchHistoryTopOffset)
                        VStack(alignment: .leading, spacing: 0.0) {
                            ForEach(history, id: \.self) { term in
                                Button {
                                    searchText = term
                                    saveSearchHistory(term)
                                    performSearch()
                                    isSearchFieldFocused = false
                                } label: {
                                    HStack(spacing: 10.0) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundStyle(.secondary)
                                            .font(.subheadline)
                                        Text(term)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14.0)
                                    .padding(.vertical, 10.0)
                                    .contentShape(.rect)
                                }
                                if term != history.last {
                                    Divider()
                                        .padding(.leading, 40.0)
                                }
                            }
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(.rect(cornerRadius: 12.0))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .padding([.leading, .trailing], 20.0)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.smooth.speed(2), value: isSearchFieldFocused)
                }
            }
        }
        .onAppear {
            Task {
                do {
                    let albums = try await DataActor.shared.albumsWithCounts(in: parentAlbum, sortedBy: albumSort)
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
            if newValue.isEmpty && isSearching {
                searchResults = []
                isSearching = false
            } else if !newValue.isEmpty {
                performSearch()
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
    }

    /// Offset to position search history just below the search bar
    private var searchHistoryTopOffset: CGFloat {
        // title height + divider + search bar area
        #if targetEnvironment(macCatalyst)
        return 90.0
        #else
        return 100.0
        #endif
    }

    func close() {
        NotificationCenter.default.post(name: NSNotification.Name("close"), object: nil)
    }

    // MARK: - Search

    func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        Task {
            do {
                let results = try await DataActor.shared.searchAlbums(matching: trimmed, sortedBy: albumSort)
                await MainActor.run {
                    searchResults = results
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }

    // MARK: - Search History

    func searchHistory() -> [String] {
        let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")
        return defaults?.stringArray(forKey: Self.searchHistoryKey) ?? []
    }

    func saveSearchHistory(_ term: String) {
        let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")
        var history = defaults?.stringArray(forKey: Self.searchHistoryKey) ?? []
        history.removeAll { $0 == term }
        history.insert(term, at: 0)
        if history.count > Self.maxHistoryCount {
            history = Array(history.prefix(Self.maxHistoryCount))
        }
        defaults?.set(history, forKey: Self.searchHistoryKey)
    }
}
