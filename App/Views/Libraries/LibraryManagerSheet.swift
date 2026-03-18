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
    @State var libraryToEdit: PicLibrary?

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
                .sheet(item: $libraryToEdit) { library in
                    EditLibrarySheet(library: library)
                        .environmentObject(libraryManager)
                        .environmentObject(navigation)
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
        Button {
            libraryToEdit = library
        } label: {
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
        }
        .tint(.primary)
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

}
