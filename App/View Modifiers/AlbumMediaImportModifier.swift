//
//  AlbumMediaImportModifier.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/04/02.
//

import PhotosUI
import SwiftUI

struct AlbumMediaImportModifier: ViewModifier {
    @Binding var isPhotosPickerPresented: Bool
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var isVideosPickerPresented: Bool
    @Binding var selectedVideoItems: [PhotosPickerItem]
    @Binding var isFileImporterPresented: Bool
    @Binding var isFileImportSheetPresented: Bool
    var onPhotosSelected: ([PhotosPickerItem]) -> Void
    var onVideosSelected: ([PhotosPickerItem]) -> Void
    var onFilesImported: ([(filename: String, data: Data)]) -> Void

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $isPhotosPickerPresented,
                          selection: $selectedPhotoItems,
                          matching: .images,
                          photoLibrary: .shared())
            .photosPicker(isPresented: $isVideosPickerPresented,
                          selection: $selectedVideoItems,
                          matching: .videos,
                          photoLibrary: .shared())
            .modifier(FileImportModifier(
                isFileImporterPresented: $isFileImporterPresented,
                isFileImportSheetPresented: $isFileImportSheetPresented,
                onFilesImported: onFilesImported
            ))
            .onChange(of: selectedPhotoItems) { _, newValue in
                if !newValue.isEmpty {
                    onPhotosSelected(newValue)
                }
            }
            .onChange(of: selectedVideoItems) { _, newValue in
                if !newValue.isEmpty {
                    onVideosSelected(newValue)
                }
            }
    }
}
