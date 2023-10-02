//
//  MainTabView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            AlbumView()
                .tabItem {
                    Label("TabTitle.Collection", systemImage: "photo.stack.fill")
                }
            MoreView()
                .tabItem {
                    Label("TabTitle.More", systemImage: "ellipsis")
                }
        }
    }
}
