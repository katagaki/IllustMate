//
//  PicMateApp.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI
import SwiftData

@main
struct IllustMateApp: App {

    @StateObject var tabManager = TabManager()
    @StateObject var navigationManager = NavigationManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Album.self, Illustration.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema,
                                                    isStoredInMemoryOnly: false,
                                                    cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    MainTabView()
                } else {
                    MainSplitView()
                }
            }
            .environmentObject(tabManager)
            .environmentObject(navigationManager)
            .task {
                createIfNotExists(illustrationsFolder)
                createIfNotExists(thumbnailsFolder)
                createIfNotExists(importsFolder)
                createIfNotExists(orphansFolder)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    func createIfNotExists(_ url: URL?) {
        if let url = url, !directoryExistsAtPath(url) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }
    }

    func directoryExistsAtPath(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = true
        let exists = FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
