//
//  IllustMateApp.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI
import SwiftData

@main
struct IllustMateApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Album.self, Illustration.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
