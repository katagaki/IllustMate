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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(album.name, text: $newAlbumName)
                        .textInputAutocapitalization(.words)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    album.name = newAlbumName.trimmingCharacters(in: .whitespaces)
                    dismiss()
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
        .task {
            newAlbumName = album.name
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}
