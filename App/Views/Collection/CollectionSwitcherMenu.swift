//
//  CollectionSwitcherMenu.swift
//  PicMate
//
//  Created by Claude on 2026/03/17.
//

import SwiftUI

struct CollectionSwitcherMenu: View {

    @EnvironmentObject var collectionManager: CollectionManager
    @EnvironmentObject var navigation: NavigationManager

    @Binding var isCollectionManagerPresented: Bool

    var body: some View {
        Menu {
            ForEach(collectionManager.collections) { collection in
                Button {
                    guard collection.id != collectionManager.currentCollection.id else { return }
                    collectionManager.switchCollection(to: collection)
                    navigation.signalDataDeleted()
                } label: {
                    if collection.id == collectionManager.currentCollection.id {
                        Label(collectionManager.displayName(for: collection),
                              systemImage: "checkmark")
                    } else {
                        Text(collectionManager.displayName(for: collection))
                    }
                }
            }
            Divider()
            Button {
                isCollectionManagerPresented = true
            } label: {
                Label(String(localized: "Collections.Manage", table: "Collections"),
                      systemImage: "slider.horizontal.3")
            }
        } label: {
            Label(collectionManager.displayName(for: collectionManager.currentCollection),
                  systemImage: "square.stack.3d.up")
        }
    }
}
