//
//  RenameAlbumView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/04.
//

import Komponents
import SwiftUI

struct RenameAlbumView: View {

    @Environment(\.dismiss) var dismiss
    @State var album: Album
    @State var newAlbumName: String = ""
    @FocusState var focusedField: FocusedField?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(album.name, text: $newAlbumName)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .newAlbumName)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task {
                        await actor.renameAlbum(withID: album.persistentModelID, to: newAlbumName)
                        await MainActor.run {
                            dismiss()
                        }
                    }
                } label: {
                    Text("Shared.Rename")
                        .bold()
                        .padding(4.0)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(newAlbumName.trimmingCharacters(in: .whitespaces) == "")
                .frame(maxWidth: .infinity)
                .padding(20.0)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Shared.Cancel", role: .cancel) {
                        newAlbumName = ""
                        dismiss()
                    }
                }
            }
            .navigationTitle("ViewTitle.Albums.Rename")
            .navigationBarTitleDisplayMode(.inline)
        }
#if targetEnvironment(macCatalyst)
        .defaultFocus($focusedField, .newAlbumName)
#else
        .onAppear {
            focusedField = .newAlbumName
        }
#endif
        .task {
            newAlbumName = album.name
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    enum FocusedField {
        case newAlbumName
    }
}
