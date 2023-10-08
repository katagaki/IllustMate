//
//  NewAlbumView.swift
//  PicMate
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
                    Button("Shared.Cancel", role: .cancel) {
                        newAlbumName = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Shared.Create") {
                        let newAlbum = Album(name: newAlbumName.trimmingCharacters(in: .whitespaces))
                        if let albumToAddTo {
                            albumToAddTo.addChildAlbum(newAlbum)
                        } else {
                            modelContext.insert(newAlbum)
                        }
                        dismiss()
                    }
                    .disabled(newAlbumName.trimmingCharacters(in: .whitespaces) == "")
                }
            }
            .navigationTitle("ViewTitle.Albums.Create")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.fraction(0.25)])
        .interactiveDismissDisabled()
    }
}
