//
//  MainSplitView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/07.
//

import SwiftUI

struct MainSplitView: View {

    @EnvironmentObject var navigation: NavigationManager
    @Environment(ViewerManager.self) var viewer
    @Environment(PictureInPictureManager.self) var pipManager

    @Namespace var namespace

    @State var albums: [Album] = []
    @State var selectedView: ViewPath? = .collection

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedView) {
                Section {
                    NavigationLink(value: ViewPath.collection) {
                        Label {
                            Text("ViewTitle.Collection")
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
                            Text("ViewTitle.Albums")
                        } icon: {
                            Image(systemName: "rectangle.stack.fill")
#if targetEnvironment(macCatalyst)
                                .resizable()
                                .frame(width: 16.0, height: 16.0)
#endif
                        }
                    }
                    NavigationLink(value: ViewPath.pics) {
                        Label {
                            Text("ViewTitle.Pics")
                        } icon: {
                            Image(systemName: "photo.on.rectangle.angled")
                        }
                    }
                    NavigationLink(value: ViewPath.more) {
                        Label("ViewTitle.More", systemImage: "ellipsis")
                    }
                }
                Section {
                    ForEach(albums) { album in
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
                case .pics: PicsView()
                case .more: MoreView()
                case .album(let album): AlbumNavigationStack(album: album)
                default: Color.clear
                }
            }
            .navigationSplitViewColumnWidth(375.0)
        } detail: {
            if let pic = viewer.displayedPic {
                PicViewer(pic: pic)
                    .id(pic.id)
            } else {
                ContentUnavailableView("Shared.SelectAPic", systemImage: "photo.on.rectangle.angled")
            }
        }
        .task {
            do {
                albums = try await DataActor.shared.albumsWithCounts(in: nil, sortedBy: .nameAscending)
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
        .onChange(of: pipManager.isPreparing) { _, isPreparing in
            if isPreparing {
                viewer.displayedPic = nil
                viewer.displayedImage = nil
                viewer.displayedThumbnail = nil
            }
        }
        .onChange(of: navigation.dataVersion) { _, _ in
            albums = []
            selectedView = .collection
            viewer.displayedPic = nil
            viewer.displayedImage = nil
            viewer.displayedThumbnail = nil
            viewer.allPics = []
            Task {
                do {
                    albums = try await DataActor.shared.albumsWithCounts(in: nil, sortedBy: .nameAscending)
                } catch {
                    debugPrint(error.localizedDescription)
                }
            }
        }
    }
}
