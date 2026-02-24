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
    @State var isImportingBackup: Bool = false
    @State var importedURL: URL?

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
            .onOpenURL { url in
                if url.pathExtension == "pics" {
                    importedURL = url
                }
            }
            .onChange(of: importedURL) { _, newValue in
                if newValue != nil {
                    isImportingBackup = true
                }
            }
            .sheet(isPresented: $isImportingBackup) {
                importedURL = nil
            } content: {
                if let importedURL {
                    RestoreBackupView(backupURL: importedURL)
                } else {
                    ProgressView()
                }
            }
        }
#if targetEnvironment(macCatalyst)
        .defaultSize(CGSize(width: 880.0, height: 680.0))
#endif
    }
}
