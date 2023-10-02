//
//  MainTabView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            AlbumsView()
                .tabItem {
                    Label("Albums", systemImage: "photo.stack.fill")
                }
            NavigationStack {
                MoreList(repoName: "katagaki/IllustMate") { }
            }
            .tabItem {
                Label("More", systemImage: "ellipsis")
            }
        }
    }
}
