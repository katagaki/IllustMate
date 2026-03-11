//
//  NewAlbumView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftUI

struct NewAlbumView: View {

    @Environment(\.dismiss) var dismiss
    @State var albumToAddTo: Album?
    @State var newAlbumName: String = ""
    @FocusState var focusedField: FocusedField?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Albums.Create.Placeholder", text: $newAlbumName)
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
                            let newAlbum = await DataActor.shared.createAlbum(newAlbumName)
                            if let albumToAddTo {
                                await DataActor.shared.addAlbum(withID: newAlbum.id,
                                                     toAlbumWithID: albumToAddTo.id)
                            }
                            dismiss()
                        }
                    }
                    .disabled(newAlbumName.trimmingCharacters(in: .whitespaces) == "")
                }
            }
            .navigationTitle("ViewTitle.Albums.Create")
            .navigationBarTitleDisplayMode(.inline)
        }
#if targetEnvironment(macCatalyst)
        .defaultFocus($focusedField, .newAlbumName)
#else
        .onAppear {
            focusedField = .newAlbumName
        }
#endif
        .phonePresentationDetents([.height(200.0), .medium])
        .interactiveDismissDisabled()
    }

    enum FocusedField {
        case newAlbumName
    }
}
