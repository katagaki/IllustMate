//
//  AlbumsView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/18.
//

import NavigationTransitions
import SwiftData
import SwiftUI

struct AlbumsView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    @Environment(ConcurrencyManager.self) var concurrency
    @EnvironmentObject var navigationManager: NavigationManager

    let actor = DataActor(modelContainer: sharedModelContainer)

    @Namespace var illustrationTransitionNamespace

    @State var albums: [Album] = []
    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle", store: defaults) var style: ViewStyle

    @State var viewerManager = ViewerManager()

    @AppStorage(wrappedValue: true, "DebugThreadSafety") var useThreadSafeLoading: Bool

    var body: some View {
        NavigationStack(path: $navigationManager.albumsTabPath) {
            ScrollView(.vertical) {
                AlbumsSection(albums: $albums, style: $style) { _ in }
            }
            .navigationDestination(for: ViewPath.self, destination: { viewPath in
                switch viewPath {
                case .album(let album): AlbumView(namespace: illustrationTransitionNamespace,
                                                  currentAlbum: album,
                                                  viewerManager: $viewerManager)
                default: Color.clear
                }
            })
            .navigationTitle("ViewTitle.Albums")
        }
        .illustrationViewerOverlay(namespace: illustrationTransitionNamespace, manager: $viewerManager)
#if targetEnvironment(macCatalyst)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Shared.Refresh") {
                    refreshAlbums()
                }
            }
        }
#else
        .navigationTransition(.default, interactivity: .pan)
        .refreshable {
            refreshAlbums()
        }
#endif
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
        if useThreadSafeLoading {
            Task.detached(priority: .userInitiated) {
                do {
                    let albums = try await actor.albums()
                    await MainActor.run {
                        self.albums = albums
                    }
                } catch {
                    debugPrint(error.localizedDescription)
                }
            }
        } else {
            concurrency.queue.addOperation {
                withAnimation(.snappy.speed(2)) {
                    do {
                        var fetchDescriptor = FetchDescriptor<Album>(
                            sortBy: [SortDescriptor(\.name)])
                        fetchDescriptor.propertiesToFetch = [\.name, \.coverPhoto]
                        albums = try modelContext.fetch(fetchDescriptor)
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
            }
        }
    }
}
