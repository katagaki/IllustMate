//
//  AlbumsView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/18.
//

import SwiftData
import SwiftUI

struct AlbumsView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var navigationManager: NavigationManager

    let actor = DataActor(modelContainer: sharedModelContainer)

    @Namespace var illustrationTransitionNamespace

    @State var albums: [Album] = []
    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle", store: defaults) var style: ViewStyle

    @State var viewerManager = ViewerManager()

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationManager.albumsTabPath) {
                ScrollView(.vertical) {
                    AlbumsSection(albums: albums, style: $style) { _ in }
                }
                .navigationDestination(for: ViewPath.self, destination: { viewPath in
                    switch viewPath {
                    case .album(let album): AlbumView(namespace: illustrationTransitionNamespace,
                                                      currentAlbum: album,
                                                      viewerManager: $viewerManager)
                    default: Color.clear
                    }
                })
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
        .illustrationViewerOverlay(namespace: illustrationTransitionNamespace, manager: $viewerManager)
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
        Task.detached(priority: .background) {
            do {
                let albums = try await actor.albums(sortedBy: .nameAscending)
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
