//
//  AlbumsView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/18.
//

import SwiftData
import SwiftUI

struct AlbumsView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(ViewerManager.self) var viewer

    @Namespace var namespace

    @State var albums: [Album] = []
    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle", store: defaults) var style: ViewStyle

    @State var viewerManager = ViewerManager()

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationManager.albumsTabPath) {
                ScrollView(.vertical) {
                    AlbumsSection(albums: albums, style: $style) { _ in }
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
                let albumIDs = try await actor.albumIDs(sortedBy: .nameAscending)
                await MainActor.run {
                    let fetchedAlbums = albumIDs.compactMap { modelContext[$0, as: Album.self] }
                    doWithAnimation {
                        self.albums = fetchedAlbums
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
}
