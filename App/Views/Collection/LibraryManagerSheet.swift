//
//  LibraryManagerSheet.swift
//  PicMate
//
//  Created by Claude on 2026/03/17.
//

import Komponents
import SwiftUI

struct LibraryManagerSheet: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var navigation: NavigationManager

    @State var isCreatingLibrary: Bool = false
    @State var newLibraryName: String = ""
    @State var libraryToRename: PicLibrary?
    @State var renameText: String = ""
    @State var libraryToDelete: PicLibrary?
    @State var deleteConfirmationCode: String = ""
    @State var expectedDeleteCode: String = ""

    var body: some View {
        NavigationStack {
            libraryList
                .navigationTitle(String(localized: "Libraries.Title", table: "Libraries"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isCreatingLibrary = true
                            newLibraryName = ""
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
                .alert(String(localized: "Libraries.New", table: "Libraries"),
                       isPresented: $isCreatingLibrary) {
                    createLibraryAlertContent
                }
                .alert(String(localized: "Libraries.Rename", table: "Libraries"),
                       isPresented: Binding(
                        get: { libraryToRename != nil },
                        set: { if !$0 { libraryToRename = nil } }
                       )) {
                    renameLibraryAlertContent
                }
                .alert(String(localized: "Libraries.Delete.Title", table: "Libraries"),
                       isPresented: Binding(
                        get: { libraryToDelete != nil },
                        set: { if !$0 { libraryToDelete = nil } }
                       )) {
                    deleteLibraryAlertContent
                } message: {
                    Text("Libraries.Delete.Message \(expectedDeleteCode)", tableName: "Libraries")
                }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private var libraryList: some View {
        List {
            ForEach(libraryManager.libraries) { library in
                libraryRow(for: library)
            }
        }
    }

    private func libraryRow(for library: PicLibrary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2.0) {
                Text(libraryManager.displayName(for: library))
                    .fontWeight(
                        library.id == libraryManager.currentLibrary.id
                        ? .semibold : .regular
                    )
                if library.isDefault {
                    Text("Libraries.Default.Description", tableName: "Libraries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if library.id == libraryManager.currentLibrary.id {
                Image(systemName: "checkmark")
                    .foregroundStyle(.accent)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !library.isDefault {
                Button(role: .destructive) {
                    expectedDeleteCode = String(format: "%06d", Int.random(in: 0...999_999))
                    deleteConfirmationCode = ""
                    libraryToDelete = library
                } label: {
                    Label("Shared.Delete", systemImage: "trash")
                }
                Button {
                    renameText = library.name
                    libraryToRename = library
                } label: {
                    Label("Shared.Rename", systemImage: "pencil")
                }
                .tint(.orange)
            }
        }
        .contextMenu {
            if !library.isDefault {
                Button {
                    renameText = library.name
                    libraryToRename = library
                } label: {
                    Label("Shared.Rename", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    expectedDeleteCode = String(format: "%06d", Int.random(in: 0...999_999))
                    deleteConfirmationCode = ""
                    libraryToDelete = library
                } label: {
                    Label("Shared.Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var createLibraryAlertContent: some View {
        TextField(String(localized: "Libraries.New.Placeholder", table: "Libraries"),
                  text: $newLibraryName)
        Button(String(localized: "Shared.Create", table: "Libraries")) {
            guard !newLibraryName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            Task {
                _ = await libraryManager.createLibrary(name: newLibraryName)
            }
        }
        Button("Shared.Cancel", role: .cancel) { }
    }

    @ViewBuilder
    private var renameLibraryAlertContent: some View {
        TextField(String(localized: "Libraries.Rename.Placeholder", table: "Libraries"),
                  text: $renameText)
        Button(String(localized: "Shared.Rename", table: "Libraries")) {
            guard let library = libraryToRename,
                  !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            Task {
                await libraryManager.renameLibrary(library, to: renameText)
            }
            libraryToRename = nil
        }
        Button("Shared.Cancel", role: .cancel) {
            libraryToRename = nil
        }
    }

    @ViewBuilder
    private var deleteLibraryAlertContent: some View {
        TextField("", text: $deleteConfirmationCode, prompt: Text(expectedDeleteCode))
            .keyboardType(.numberPad)
        Button(String(localized: "Shared.Delete", table: "Libraries"), role: .destructive) {
            guard let library = libraryToDelete,
                  deleteConfirmationCode == expectedDeleteCode else { return }
            let wasCurrentLibrary = library.id == libraryManager.currentLibrary.id
            Task {
                await libraryManager.deleteLibrary(library)
                if wasCurrentLibrary {
                    navigation.signalDataDeleted()
                }
            }
            libraryToDelete = nil
        }
        Button("Shared.Cancel", role: .cancel) {
            libraryToDelete = nil
        }
    }
}
