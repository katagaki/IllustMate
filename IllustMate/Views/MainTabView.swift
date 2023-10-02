//
//  MainTabView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI

struct MainTabView: View {

    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var navigationManager: NavigationManager

    var body: some View {
        TabView(selection: $tabManager.selectedTab) {
            AlbumView()
                .tabItem {
                    Label("TabTitle.Collection", systemImage: "photo.stack.fill")
                }
                .tag(TabType.collection)
            MoreView()
                .tabItem {
                    Label("TabTitle.More", systemImage: "ellipsis")
                }
                .tag(TabType.more)
        }
        .onReceive(tabManager.$selectedTab, perform: { newValue in
            if newValue == tabManager.previouslySelectedTab {
                navigationManager.popToRoot(for: newValue)
            }
            tabManager.previouslySelectedTab = newValue
        })
    }
}
