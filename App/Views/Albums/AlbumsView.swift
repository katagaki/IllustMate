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
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(alignment: .center, spacing: 8.0) {
                            Text("\(albums.count)")
                                .foregroundStyle(.secondary)
#if targetEnvironment(macCatalyst)
                            Button("Shared.Refresh") {
                                refreshAlbums()
                            }
#endif
                        }
                    }
                }
#if !targetEnvironment(macCatalyst)
                .refreshable {
                    refreshAlbums()
                }
#endif
                .navigationTitle("ViewTitle.Albums")
            }
        }
        .onAppear {
            refreshAlbums()
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                refreshAlbums()
            }
        }
    }

    func refreshAlbums() {
        Task.detached(priority: .userInitiated) {
            do {
                let albums = try await dataActor.albumsWithCounts(sortedBy: .nameAscending)
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
}
