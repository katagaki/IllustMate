//
//  MainTabView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import CloudKitSyncMonitor
import SwiftUI

struct MainTabView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var navigationManager: NavigationManager
    @ObservedObject var syncMonitor = SyncMonitor.shared

    @State var isImporting: Bool = false
    @State var currentProgress: Int = 0
    @State var total: Int = 0
    @State var percentage: Int = 0

    var body: some View {
        TabView(selection: $tabManager.selectedTab) {
            CollectionView()
                .tabItem {
                    Label("TabTitle.Collection", image: "Tab.Collection")
                }
                .tag(TabType.collection)
            ImportView(isImporting: $isImporting,
                       currentProgress: $currentProgress,
                       total: $total,
                       percentage: $percentage)
                .tabItem {
                    Label("TabTitle.Import", image: "Tab.Import")
                }
                .tag(TabType.importer)
            SearchView()
                .tabItem {
                    Label("TabTitle.Search", systemImage: "magnifyingglass")
                }
                .tag(TabType.search)
            MoreView()
                .tabItem {
                    Label("TabTitle.More", systemImage: "ellipsis")
                }
                .tag(TabType.more)
        }
        .overlay {
            ZStack(alignment: .topTrailing) {
                Color.clear
                if syncMonitor.syncStateSummary.inProgress {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28.0, height: 28.0)
                        .symbolRenderingMode(.hierarchical)
                        .padding([.trailing], 20.0)
                        .padding([.top], 2.0)
                }
            }
        }
        .overlay {
            if isImporting {
                ProgressAlert(title: "Import.Importing", percentage: $percentage)
                    .ignoresSafeArea()
            }
        }
        .onReceive(tabManager.$selectedTab, perform: { newValue in
            if newValue == tabManager.previouslySelectedTab {
                navigationManager.popToRoot(for: newValue)
            }
            tabManager.previouslySelectedTab = newValue
        })
    }
}
