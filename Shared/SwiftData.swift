//
//  Database.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/12.
//

import Foundation
import SQLite

let sharedDatabase: Connection = {
    let dbURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent("IllustMate.sqlite")
    do {
        let connection = try Connection(dbURL.path)
        return connection
    } catch {
        fatalError("Could not open SQLite database: \(error)")
    }
}()

let actor = DataActor(sharedDatabase)
