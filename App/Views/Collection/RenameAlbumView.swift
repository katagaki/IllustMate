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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        newAlbumName = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        Task {
                            await DataActor.shared.renameAlbum(withID: album.id, to: newAlbumName)
                            await MainActor.run {
                                dismiss()
                            }
                        }
                    }
                    .disabled(newAlbumName.trimmingCharacters(in: .whitespaces) == "")
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
        .phonePresentationDetents([.height(200.0)])
        .interactiveDismissDisabled()
    }

    enum FocusedField {
        case newAlbumName
    }
}
