//
//  MainSplitView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/07.
//

import SwiftData
import SwiftUI

struct MainSplitView: View {

    @Query(FetchDescriptor<Album>(predicate: #Predicate { $0.parentAlbum == nil },
                                  sortBy: [SortDescriptor<Album>(\.name)])) var albums: [Album]

    @State var viewPath: ViewPath? = .collection

    @State var progressAlertManager = ProgressAlertManager()

    var body: some View {
        NavigationSplitView {
            List(selection: $viewPath) {
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
                NavigationLink(value: ViewPath.illustrations) {
                    Label {
                        Text("TabTitle.Illustrations")
                    } icon: {
                        Image(systemName: "photo.stack.fill")
#if targetEnvironment(macCatalyst)
                            .resizable()
                            .frame(width: 16.0, height: 16.0)
#endif
                    }
                }
                NavigationLink(value: ViewPath.importer) {
                    Label {
                        Text("TabTitle.Import")
                    } icon: {
                        Image("Tab.Import")
#if targetEnvironment(macCatalyst)
                            .resizable()
                            .frame(width: 16.0, height: 16.0)
#endif
                    }
                }
                NavigationLink(value: ViewPath.more) {
                    Label("TabTitle.More", systemImage: "ellipsis")
                }
                Divider()
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
            }
#if targetEnvironment(macCatalyst)
            .navigationSplitViewColumnWidth(170.0)
#endif
        } detail: {
            ZStack {
                switch viewPath {
                case .collection:
                    CollectionView()
                case .illustrations:
                    IllustrationsView()
                case .importer:
                    ImportView(progressAlertManager: $progressAlertManager)
                case .more:
                    MoreView(progressAlertManager: $progressAlertManager)
                case .album(let album):
                    AlbumNavigationStack(album: album)
                        .id(album.id)
                default: Color.clear
                }
            }
        }
        .overlay {
            if progressAlertManager.isDisplayed {
                ProgressAlert(manager: $progressAlertManager)
                    .ignoresSafeArea()
            }
        }
    }
}
