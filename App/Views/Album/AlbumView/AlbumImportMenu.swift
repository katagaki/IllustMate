//
//  AlbumImportMenu.swift
//  PicMate
//
//  Created by Claude on 2026/03/23.
//

import SwiftUI

struct AlbumImportMenu: View {

    @Binding var isPhotosPickerPresented: Bool
    @Binding var isBrowsingAlbums: Bool
    @Binding var isBrowsingFolders: Bool
    var presentFileImporter: () -> Void

    var body: some View {
        Menu("Shared.Import", systemImage: "square.and.arrow.down.on.square") {
            Section(String(localized: "Import.Section.FromPhotosApp", table: "Import")) {
                Button {
                    isPhotosPickerPresented = true
                } label: {
                    Label(String(localized: "Import.SelectPhotos", table: "Import"),
                          systemImage: "photo.on.rectangle.angled")
                }
                Button {
                    isBrowsingAlbums = true
                } label: {
                    Label(String(localized: "Import.BrowseAlbums", table: "Import"),
                          systemImage: "rectangle.stack")
                }
                Button {
                    isBrowsingFolders = true
                } label: {
                    Label(String(localized: "Import.SelectFolder", table: "Import"),
                          systemImage: "folder")
                }
            }
            Section(String(localized: "Import.Section.FromFilesApp", table: "Import")) {
                Button {
                    presentFileImporter()
                } label: {
                    Label(String(localized: "Import.SelectFromFiles", table: "Import"),
                          systemImage: "document")
                }
            }
        }
    }
}
