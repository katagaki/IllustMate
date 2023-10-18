//
//  MainTabView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI

struct MainTabView: View {

    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var navigationManager: NavigationManager

    @State var progressAlertManager = ProgressAlertManager()

    var body: some View {
        TabView(selection: $tabManager.selectedTab) {
            CollectionView()
                .tabItem {
                    Label("TabTitle.Collection", image: "Tab.Collection")
                }
                .tag(TabType.collection)
            AlbumsView()
                .tabItem {
                    Label("TabTitle.Albums", image: "Tab.Albums")
                }
                .tag(TabType.albums)
            IllustrationsView()
                .tabItem {
                    Label("TabTitle.Illustrations", systemImage: "photo.fill")
                }
                .tag(TabType.illustrations)
            ImportView(progressAlertManager: $progressAlertManager)
                .tabItem {
                    Label("TabTitle.Import", image: "Tab.Import")
                }
                .tag(TabType.importer)
            MoreView(progressAlertManager: $progressAlertManager)
                .tabItem {
                    Label("TabTitle.More", systemImage: "ellipsis")
                }
                .tag(TabType.more)
        }
        .overlay {
            if progressAlertManager.isDisplayed {
                ProgressAlert(manager: $progressAlertManager)
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
