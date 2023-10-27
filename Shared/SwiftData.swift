//
//  SwiftData.swift
//  Importer
//
//  Created by シン・ジャスティン on 2023/10/12.
//

import SwiftData

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

let actor = DataActor(modelContainer: sharedModelContainer)
