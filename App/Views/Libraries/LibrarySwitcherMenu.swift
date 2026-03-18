//
//  LibrarySwitcherMenu.swift
//  PicMate
//
//  Created by Claude on 2026/03/17.
//

import SwiftUI

struct LibrarySwitcherMenu: View {

    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var navigation: NavigationManager

    @Binding var isLibraryManagerPresented: Bool

    var body: some View {
        Menu {
            ForEach(libraryManager.libraries) { library in
                Button {
                    guard library.id != libraryManager.currentLibrary.id else { return }
                    libraryManager.switchLibrary(to: library)
                    navigation.signalDataDeleted()
                } label: {
                    if library.id == libraryManager.currentLibrary.id {
                        Label(libraryManager.displayName(for: library),
                              systemImage: "checkmark")
                    } else {
                        Text(libraryManager.displayName(for: library))
                    }
                }
            }
            Divider()
            Button {
                isLibraryManagerPresented = true
            } label: {
                Label(String(localized: "Libraries.Manage", table: "Libraries"),
                      systemImage: "slider.horizontal.3")
            }
        } label: {
            Label(libraryManager.displayName(for: libraryManager.currentLibrary),
                  systemImage: "square.stack.3d.up")
        }
    }
}
