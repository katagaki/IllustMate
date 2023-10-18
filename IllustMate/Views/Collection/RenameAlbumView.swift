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
    @State var album: Album?
    @State var newAlbumName: String = ""

    var body: some View {
        NavigationStack {
            List {
                if let album {
                    Section {
                        TextField(album.name, text: $newAlbumName)
                            .textInputAutocapitalization(.words)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Shared.Cancel", role: .cancel) {
                        newAlbumName = ""
                        dismiss()
                    }
                }
                if let album {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Shared.Rename") {
                            album.name = newAlbumName.trimmingCharacters(in: .whitespaces)
                            dismiss()
                        }
                        .disabled(newAlbumName.trimmingCharacters(in: .whitespaces) == "")
                    }
                }
            }
            .navigationTitle("ViewTitle.Albums.Rename")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            newAlbumName = album?.name ?? ""
        }
        .presentationDetents([.fraction(0.25)])
        .interactiveDismissDisabled()
    }
}
