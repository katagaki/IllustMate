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
    @Environment(ViewerManager.self) var viewer
    @Environment(ProgressAlertManager.self) var progressAlertManager

    var body: some View {
        TabView(selection: $tabManager.selectedTab) {
            CollectionView()
                .tabItem {
                    Label("TabTitle.Collection", image: "Tab.Collection")
                }
                .tag(TabType.collection)
//            AlbumsView()
//                .tabItem {
//                    Label("TabTitle.Albums", systemImage: "rectangle.stack.fill")
//                }
//                .tag(TabType.albums)
//            IllustrationsView()
//                .tabItem {
//                    Label("TabTitle.Illustrations", systemImage: "photo.on.rectangle.angled")
//                }
//                .tag(TabType.illustrations)
            MoreView()
                .tabItem {
                    Label("TabTitle.More", systemImage: "ellipsis")
                }
                .tag(TabType.more)
        }
        .overlay {
            if progressAlertManager.isDisplayed {
                ProgressAlert()
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
