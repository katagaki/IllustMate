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
    @State var albumToAddTo: PhotoAlbum?
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
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task {
                        do {
                            _ = try await photosActor.createAlbum(newAlbumName)
                            // Note: Adding to parent folder not supported by PhotoKit
                            dismiss()
                        } catch {
                            debugPrint("Error creating album: \(error)")
                        }
                    }
                } label: {
                    Text("Shared.Create")
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
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    enum FocusedField {
        case newAlbumName
    }
}
