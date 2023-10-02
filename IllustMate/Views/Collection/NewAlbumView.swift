//
//  NewAlbumView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftUI

struct NewAlbumView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State var albumToAddTo: Album?
    @State var newAlbumName: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Albums.Create.Placeholder", text: $newAlbumName)
                        .textInputAutocapitalization(.words)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        newAlbumName = ""
                        dismiss()
                    } label: {
                        Text("Shared.Cancel")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let newAlbum = Album(name: newAlbumName.trimmingCharacters(in: .whitespaces),
                                             dateCreated: .now)
                        if let albumToAddTo = albumToAddTo {
                            albumToAddTo.addChildAlbum(newAlbum)
                        } else {
                            modelContext.insert(newAlbum)
                        }
                        dismiss()
                    } label: {
                        Text("Shared.Create")
                    }
                    .disabled(newAlbumName.trimmingCharacters(in: .whitespaces) == "")
                }
            }
            .navigationTitle("ViewTitle.Albums.Create")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}
