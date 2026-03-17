//
//  CollectionManagerSheet.swift
//  PicMate
//
//  Created by Claude on 2026/03/17.
//

import Komponents
import SwiftUI

struct CollectionManagerSheet: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var collectionManager: CollectionManager
    @EnvironmentObject var navigation: NavigationManager

    @State var isCreatingCollection: Bool = false
    @State var newCollectionName: String = ""
    @State var collectionToRename: Collection?
    @State var renameText: String = ""
    @State var collectionToDelete: Collection?
    @State var deleteConfirmationCode: String = ""
    @State var expectedDeleteCode: String = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(collectionManager.collections) { collection in
                    HStack {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(collectionManager.displayName(for: collection))
                                .fontWeight(
                                    collection.id == collectionManager.currentCollection.id
                                    ? .semibold : .regular
                                )
                            if collection.isDefault {
                                Text("Collections.Default.Description", tableName: "Collections")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if collection.id == collectionManager.currentCollection.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accent)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !collection.isDefault {
                            Button(role: .destructive) {
                                expectedDeleteCode = String(format: "%06d", Int.random(in: 0...999_999))
                                deleteConfirmationCode = ""
                                collectionToDelete = collection
                            } label: {
                                Label("Shared.Delete", systemImage: "trash")
                            }
                            Button {
                                renameText = collection.name
                                collectionToRename = collection
                            } label: {
                                Label("Shared.Rename", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                    .contextMenu {
                        if !collection.isDefault {
                            Button {
                                renameText = collection.name
                                collectionToRename = collection
                            } label: {
                                Label("Shared.Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                expectedDeleteCode = String(format: "%06d", Int.random(in: 0...999_999))
                                deleteConfirmationCode = ""
                                collectionToDelete = collection
                            } label: {
                                Label("Shared.Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Collections.Title", table: "Collections"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isCreatingCollection = true
                        newCollectionName = ""
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "Collections.New", table: "Collections"),
                   isPresented: $isCreatingCollection) {
                TextField(String(localized: "Collections.New.Placeholder", table: "Collections"),
                          text: $newCollectionName)
                Button(String(localized: "Shared.Create", table: "Collections")) {
                    guard !newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Task {
                        _ = await collectionManager.createCollection(name: newCollectionName)
                    }
                }
                Button("Shared.Cancel", role: .cancel) { }
            }
            .alert(String(localized: "Collections.Rename", table: "Collections"),
                   isPresented: Binding(
                    get: { collectionToRename != nil },
                    set: { if !$0 { collectionToRename = nil } }
                   )) {
                TextField(String(localized: "Collections.Rename.Placeholder", table: "Collections"),
                          text: $renameText)
                Button(String(localized: "Shared.Rename", table: "Collections")) {
                    guard let collection = collectionToRename,
                          !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Task {
                        await collectionManager.renameCollection(collection, to: renameText)
                    }
                    collectionToRename = nil
                }
                Button("Shared.Cancel", role: .cancel) {
                    collectionToRename = nil
                }
            }
            .alert(String(localized: "Collections.Delete.Title", table: "Collections"),
                   isPresented: Binding(
                    get: { collectionToDelete != nil },
                    set: { if !$0 { collectionToDelete = nil } }
                   )) {
                TextField(expectedDeleteCode, text: $deleteConfirmationCode)
                    .keyboardType(.numberPad)
                Button(String(localized: "Shared.Delete", table: "Collections"), role: .destructive) {
                    guard let collection = collectionToDelete,
                          deleteConfirmationCode == expectedDeleteCode else { return }
                    let wasCurrentCollection = collection.id == collectionManager.currentCollection.id
                    Task {
                        await collectionManager.deleteCollection(collection)
                        if wasCurrentCollection {
                            navigation.signalDataDeleted()
                        }
                    }
                    collectionToDelete = nil
                }
                Button("Shared.Cancel", role: .cancel) {
                    collectionToDelete = nil
                }
            } message: {
                Text("Collections.Delete.Message \(expectedDeleteCode)", tableName: "Collections")
            }
        }
    }
}
