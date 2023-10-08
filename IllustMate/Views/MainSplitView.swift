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

    @State var isProgressAlertDisplayed: Bool = false
    @State var progressViewText: LocalizedStringKey = ""
    @State var currentProgress: Int = 0
    @State var total: Int = 0
    @State var percentage: Int = 0

    var body: some View {
        NavigationSplitView {
            List(selection: $viewPath) {
                NavigationLink(value: ViewPath.collection) {
                    Label {
                        Text("TabTitle.Collection")
                    } icon: {
                        Image("Tab.Collection")
                            .resizable()
                            .frame(width: 16.0, height: 16.0)
                    }
                }
                NavigationLink(value: ViewPath.illustrations) {
                    Label {
                        Text("TabTitle.Illustrations")
                    } icon: {
                        Image(systemName: "photo.stack.fill")
                            .resizable()
                            .frame(width: 16.0, height: 16.0)
                    }
                }
                NavigationLink(value: ViewPath.importer) {
                    Label {
                        Text("TabTitle.Import")
                    } icon: {
                        Image("Tab.Import")
                            .resizable()
                            .frame(width: 16.0, height: 16.0)
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
                                .frame(width: 16.0, height: 16.0)
                                .clipShape(RoundedRectangle(cornerRadius: 3.0))
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
                    ImportView(isImporting: $isProgressAlertDisplayed,
                               progressViewText: $progressViewText,
                               currentProgress: $currentProgress,
                               total: $total,
                               percentage: $percentage)
                case .more:
                    MoreView(isReportingProgress: $isProgressAlertDisplayed,
                             progressViewText: $progressViewText,
                             currentProgress: $currentProgress,
                             total: $total,
                             percentage: $percentage)
                case .album(let album):
                    AlbumNavigationStack(album: album)
                        .id(album.id)
                default: Color.clear
                }
            }
        }
        .overlay {
            if isProgressAlertDisplayed {
                ProgressAlert(title: progressViewText, percentage: $percentage)
                    .ignoresSafeArea()
            }
        }
    }
}
