//
//  PhotosFolderView+Sheets.swift
//  PicMate
//
//  Created on 2026/02/26.
//

import Photos
import SwiftUI

// MARK: - Sheets

extension PhotosFolderView {
    var photosNewAlbumInFolderSheet: some View {
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
                        isAddingAlbum = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        Task {
                            do {
                                let newAlbum = try await photosManager.createAlbum(named: newAlbumName)
                                try await photosManager.moveAlbum(newAlbum, into: folder)
                                await MainActor.run {
                                    newAlbumName = ""
                                    isAddingAlbum = false
                                    hasFetched = false
                                    fetchContent()
                                }
                            } catch {
                                debugPrint(error.localizedDescription)
                            }
                        }
                    }
                    .disabled(newAlbumName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("ViewTitle.Albums.Create")
            .navigationBarTitleDisplayMode(.inline)
        }
        .phonePresentationDetents([.height(200.0), .medium])
        .interactiveDismissDisabled()
    }

    func photosRenameAlbumSheet(_ collection: PHAssetCollection) -> some View {
        NavigationStack {
            List {
                Section {
                    TextField(collection.localizedTitle ?? "", text: $renameText)
                        .textInputAutocapitalization(.words)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task {
                        do {
                            try await photosManager.renameAlbum(collection, to: renameText)
                            await MainActor.run {
                                albumToRename = nil
                                renameText = ""
                                hasFetched = false
                                fetchContent()
                            }
                        } catch {
                            debugPrint(error.localizedDescription)
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
                .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
                .frame(maxWidth: .infinity)
                .padding(20.0)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        albumToRename = nil
                        renameText = ""
                    }
                }
            }
            .navigationTitle("ViewTitle.Albums.Rename")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            renameText = collection.localizedTitle ?? ""
        }
        .phonePresentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    func photosMoveFolderSheet(_ collection: PHAssetCollection) -> some View {
        NavigationStack {
            PhotosFolderPickerView(album: collection) {
                albumToMove = nil
                hasFetched = false
                fetchContent()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        albumToMove = nil
                    }
                }
            }
            .navigationTitle("Photos.MoveToFolder")
            .navigationBarTitleDisplayMode(.inline)
        }
        .phonePresentationDetents([.medium, .large])
    }
}
