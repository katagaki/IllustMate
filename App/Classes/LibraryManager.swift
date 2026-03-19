//
//  LibraryManager.swift
//  PicMate
//
//  Created by Claude on 2026/03/17.
//

import Foundation
import SwiftUI

@MainActor
class LibraryManager: ObservableObject {

    @Published var currentLibrary: PicLibrary = PicLibrary()
    @Published var libraries: [PicLibrary] = []

    @AppStorage("CurrentCollectionID",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate"))
    var currentLibraryID: String = PicLibrary.defaultID

    func loadLibraries() async {
        let allLibraries = await LibrariesActor.shared.allLibraries()
        let sorted = allLibraries.sorted { lhs, rhs in
            if lhs.isDefault { return true }
            if rhs.isDefault { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        withAnimation(.smooth.speed(2.0)) {
            libraries = sorted
        }

        // Restore last selected library
        if let saved = allLibraries.first(where: { $0.id == currentLibraryID }) {
            currentLibrary = saved
        } else {
            // Fallback to default
            currentLibrary = allLibraries.first(where: { $0.isDefault }) ?? PicLibrary()
            currentLibraryID = PicLibrary.defaultID
        }
        switchActors(to: currentLibrary.id)
    }

    func switchLibrary(to library: PicLibrary) {
        currentLibrary = library
        currentLibraryID = library.id
        switchActors(to: library.id)
        AlbumCoverCache.shared.removeAllImages()
    }

    func createLibrary(name: String) async -> PicLibrary {
        let library = await LibrariesActor.shared.createLibrary(name: name)
        await loadLibraries()
        return library
    }

    func renameLibrary(_ library: PicLibrary, to newName: String) async {
        await LibrariesActor.shared.renameLibrary(withID: library.id, to: newName)
        await loadLibraries()
        if currentLibrary.id == library.id {
            currentLibrary.name = newName.trimmingCharacters(in: .whitespaces)
        }
    }

    func deleteLibrary(_ library: PicLibrary) async {
        guard !library.isDefault else { return }
        await LibrariesActor.shared.deleteLibrary(withID: library.id)
        if currentLibrary.id == library.id {
            let defaultLibrary = PicLibrary()
            switchLibrary(to: defaultLibrary)
        }
        await loadLibraries()
    }

    private func switchActors(to libraryID: String) {
        DataActor.switchLibrary(to: libraryID)
        HashActor.switchLibrary(to: libraryID)
        CoverCacheActor.switchLibrary(to: libraryID)
        PColorActor.switchLibrary(to: libraryID)
    }

    func displayName(for library: PicLibrary) -> String {
        if library.isDefault {
            return String(localized: "Collection.Default", table: "Libraries")
        }
        return library.name
    }
}
