//
//  MainSplitView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/07.
//

import SwiftData
import SwiftUI

struct MainSplitView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(ProgressAlertManager.self) var progressAlertManager
    @Environment(ViewerManager.self) var viewer

    @Namespace var namespace

    @State var albums: [Album] = []

    @State var selectedView: ViewPath? = .collection

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedView) {
                Section {
                    NavigationLink(value: ViewPath.collection) {
                        Label {
                            Text("TabTitle.Collection")
                        } icon: {
                            Image("Tab.Collection")
#if targetEnvironment(macCatalyst)
                                .resizable()
                                .frame(width: 16.0, height: 16.0)
#endif
                        }
                    }
                    NavigationLink(value: ViewPath.albums) {
                        Label {
                            Text("TabTitle.Albums")
                        } icon: {
                            Image(systemName: "rectangle.stack.fill")
#if targetEnvironment(macCatalyst)
                                .resizable()
                                .frame(width: 16.0, height: 16.0)
#endif
                        }
                    }
                    NavigationLink(value: ViewPath.illustrations) {
                        Label {
                            Text("TabTitle.Illustrations")
                        } icon: {
                            Image(systemName: "photo.on.rectangle.angled")
                        }
                    }
                    NavigationLink(value: ViewPath.more) {
                        Label("TabTitle.More", systemImage: "ellipsis")
                    }
                }
                Section {
                    ForEach(albums, id: \.id) { album in
                        NavigationLink(value: ViewPath.album(album: album)) {
                            Label {
                                Text(album.name)
                            } icon: {
                                Image(uiImage: album.cover())
                                    .resizable()
#if targetEnvironment(macCatalyst)
                                    .frame(width: 16.0, height: 16.0)
                                    .clipShape(.rect(cornerRadius: 3.0))
#else
                                    .frame(width: 28.0, height: 28.0)
                                    .clipShape(.rect(cornerRadius: 6.0))
#endif
                            }
                        }
                    }
                } header: {
                    Text("Shared.Albums")
                }
            }
#if targetEnvironment(macCatalyst)
            .navigationSplitViewColumnWidth(170.0)
#endif
        } content: {
            Group {
                switch selectedView {
                case .collection: CollectionView()
                case .albums: AlbumsView()
                case .illustrations: IllustrationsView()
                case .more: MoreView()
                case .album(let album): AlbumNavigationStack(album: album)
                default: Color.clear
                }
            }
            .navigationSplitViewColumnWidth(375.0)
        } detail: {
            if let image = viewer.displayedImage,
               let illustration = viewer.displayedIllustration {
                IllustrationViewer(illustration: illustration, displayedImage: image)
                    .id(illustration.id)
            } else {
                ContentUnavailableView("Shared.SelectAnIllustration", systemImage: "photo.on.rectangle.angled")
            }
        }
        .overlay {
            if progressAlertManager.isDisplayed {
                ProgressAlert()
                    .ignoresSafeArea()
            }
        }
        .task {
            await loadAlbums()
        }
    }

    func loadAlbums() async {
        do {
            let albumIDs = try await actor.albumIDsWithNilParent()
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
