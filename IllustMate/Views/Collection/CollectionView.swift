//
//  CollectionView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import CloudKitSyncMonitor
import Komponents
import SwiftUI
import SwiftData

struct CollectionView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager
    @ObservedObject var syncMonitor = SyncMonitor.shared
    @Query(sort: \Album.name,
           order: .forward,
           animation: .snappy.speed(2)) var albums: [Album]
    @Query(sort: \Illustration.dateAdded,
           order: .forward,
           animation: .snappy.speed(2)) var illustrations: [Illustration]

    @State var isAddingAlbum: Bool = false

    var body: some View {
        NavigationStack(path: $navigationManager.collectionTabPath) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 20.0) {
                    AlbumsSection(albums: albums.filter({ $0.parentAlbum == nil}), isAddingAlbum: $isAddingAlbum)
                    IllustrationsSection(
                        illustrations: illustrations.filter({ illustration in
                            if let albums = illustration.containingAlbums, albums.isEmpty {
                                return true
                            }
                            return false
                        }),
                        selectableAlbums: albums.filter({ $0.parentAlbum == nil }),
                        isRootAlbum: true)
                }
                .padding([.top], 20.0)
            }
            .navigationDestination(for: ViewPath.self, destination: { viewPath in
                switch viewPath {
                case .album(let album): AlbumView(currentAlbum: album)
                case .illustrationViewer(let illustration): IllustrationViewerView(illustration: illustration)
                default: Color.clear
                }
            })
            .sheet(isPresented: $isAddingAlbum) {
                NewAlbumView(albumToAddTo: nil)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if syncMonitor.syncStateSummary.inProgress {
                        Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                            .resizable()
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .navigationTitle("ViewTitle.Collection")
        }
    }
}
