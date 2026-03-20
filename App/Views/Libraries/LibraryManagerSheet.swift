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
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isCreatingLibrary = true
                            newLibraryName = ""
                        } label: {
                            Image(systemName: "plus")
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
        .phonePresentationDetents([.medium, .large])
    }

    private var libraryList: some View {
        List {
            ForEach(libraryManager.libraries) { library in
                libraryRow(for: library)
            }
        }
        .listStyle(.plain)
    }

    private func libraryRow(for library: PicLibrary) -> some View {
        Button {
            libraryToEdit = library
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2.0) {
                    Text(libraryManager.displayName(for: library))
                    if library.isDefault {
                        Text("Libraries.Default.Description", tableName: "Libraries")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if library.id == libraryManager.currentLibrary.id {
                    Text("Libraries.Active", tableName: "Libraries")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.accent, in: .capsule)
                }
            }
        }
        .tint(.primary)
        .swipeActions(edge: .leading) {
            if library.id != libraryManager.currentLibrary.id {
                Button {
                    setLibraryActive(library)
                } label: {
                    Label(String(localized: "Libraries.SetActive.Short", table: "Libraries"),
                          systemImage: "checkmark.circle")
                }
                .tint(.accent)
            }
        }
    }

    private func setLibraryActive(_ library: PicLibrary) {
        libraryManager.switchLibrary(to: library)
        navigation.signalDataDeleted()
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
