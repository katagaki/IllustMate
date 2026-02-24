//
//  PicMateApp.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI

@main
struct IllustMateApp: App {

    @StateObject var tabManager = TabManager()
    @StateObject var navigation = NavigationManager()
    @State var viewer = ViewerManager()
    @State var concurrency = ConcurrencyManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    CollectionView()
                } else {
                    MainSplitView()
                }
            }
            .environmentObject(tabManager)
            .environmentObject(navigation)
            .environment(viewer)
            .environment(concurrency)
        }
#if targetEnvironment(macCatalyst)
        .defaultSize(CGSize(width: 880.0, height: 680.0))
#endif
    }
}
