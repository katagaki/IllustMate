//
//  ImporterView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ImporterView: View {

    @Environment(\.dismiss) var dismiss

    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State var selectedFileURLs: [URL] = []
    @State var selectedLoadedFiles: [(filename: String, data: Data)] = []
    @State var selectedAlbum: Album?

    @State var isImporting: Bool = false
    @State var isImportCompleted: Bool = false
    @State var importCurrentCount: Int = 0
    @State var importTotalCount: Int = 0
    @State var importCompletedCount: Int = 0

    @State var isFileImporterPresented: Bool = false
    @State var isFileImportSheetPresented: Bool = false

    @State var navigationPath = NavigationPath()

    var selectedItemCount: Int {
        selectedPhotoItems.count + selectedFileURLs.count + selectedLoadedFiles.count
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView(.vertical) {
                VStack(alignment: .center, spacing: 20.0) {
                    if !isImportCompleted {
                        if !isImporting {
                            VStack(alignment: .leading, spacing: 8.0) {
                                Text("Import.Section.FromPhotosApp", tableName: "Import")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)
                                Text("Import.Section.Photos.Description", tableName: "Import")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                                Group {
                                    PhotosPicker(selection: $selectedPhotoItems,
                                                 matching: .images,
                                                 photoLibrary: .shared()) {
                                        Text("Import.SelectPhotos", tableName: "Import")
                                            .bold()
                                            .padding(4.0)
                                            .frame(maxWidth: .infinity)
                                    }
                                    Button {
                                        navigationPath.append("albumPicker")
                                    } label: {
                                        Text("Import.BrowseAlbums", tableName: "Import")
                                            .bold()
                                            .padding(4.0)
                                            .frame(maxWidth: .infinity)
                                    }
                                    Button {
                                        navigationPath.append("folderPicker")
                                    } label: {
                                        Text("Import.SelectFolder", tableName: "Import")
                                            .bold()
                                            .padding(4.0)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .buttonStyle(.glassProminent)
                                .buttonBorderShape(.capsule)
                                .disabled(isImporting)
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 8.0) {
                                Text("Import.Section.FromFilesApp", tableName: "Import")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)
                                Text("Import.Section.Files.Description", tableName: "Import")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                                Button {
                                    presentFileImporter()
                                } label: {
                                    Text("Import.SelectFromFiles", tableName: "Import")
                                        .bold()
                                        .padding(4.0)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glassProminent)
                                .buttonBorderShape(.capsule)
                                .disabled(isImporting)
                            }
                        } else {
                            StatusView(type: .inProgress, title: .importImporting,
                                       currentCount: importCurrentCount, totalCount: importTotalCount)
                        }
                    } else {
                        StatusView(type: .success, title: .importCompleted(count: importCompletedCount))
                    }
                }
                .padding(20.0)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: 16.0) {
                    if !isImportCompleted {
                        Text("Import.SelectedPhotos.\(selectedItemCount)", tableName: "Import")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            isImporting = true
                            importTotalCount = selectedItemCount
                            importPhotosAndFiles()
                        } label: {
                            Text("Import.StartImport", tableName: "Import")
                                .bold()
                                .padding(4.0)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.accent)
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.capsule)
                        .disabled(isImporting || selectedItemCount == 0)
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Text("Shared.OK")
                                .bold()
                                .padding(4.0)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.capsule)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20.0)
                .tint(.accent)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !isImporting {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("ViewTitle.Import")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { destination in
                if destination == "albumPicker" {
                    PhotosAlbumPickerView(selectedAlbum: selectedAlbum) {
                        dismiss()
                    }
                } else if destination == "folderPicker" {
                    PhotosFolderImportPickerView(selectedAlbum: selectedAlbum) {
                        dismiss()
                    }
                }
            }
            .modifier(FileImportModifier(
                isFileImporterPresented: $isFileImporterPresented,
                isFileImportSheetPresented: $isFileImportSheetPresented,
                onFilesImported: { files in selectedLoadedFiles = files }
            ))
        }
        .phonePresentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }

    func presentFileImporter() {
        #if targetEnvironment(macCatalyst)
        isFileImportSheetPresented = true
        #else
        isFileImporterPresented = true
        #endif
    }

    func importPhotosAndFiles() {
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            for selectedPhotoItem in selectedPhotoItems {
                if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                    var creationDate: Date?
                    var filename: String?
                    if let identifier = selectedPhotoItem.itemIdentifier {
                        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                        if let asset = result.firstObject {
                            creationDate = asset.creationDate
                            let resources = PHAssetResource.assetResources(for: asset)
                            filename = resources.first?.originalFilename
                        }
                    }
                    await DataActor.shared.createPic(filename ?? Pic.newFilename(), data: data,
                                                   inAlbumWithID: selectedAlbum?.id,
                                                   dateAdded: creationDate)
                }
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            // Read file data synchronously while security-scoped access is valid,
            // then perform async database work separately
            var loadedFiles: [(filename: String, data: Data)] = []
            for fileURL in selectedFileURLs {
                let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
                if let data = try? Data(contentsOf: fileURL),
                   UIImage(data: data) != nil {
                    loadedFiles.append((filename: fileURL.lastPathComponent, data: data))
                }
                if didStartAccessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            for file in loadedFiles {
                await DataActor.shared.createPic(file.filename, data: file.data,
                                               inAlbumWithID: selectedAlbum?.id)
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            // Import pre-loaded files (from Catalyst file import sheet)
            for file in selectedLoadedFiles {
                await DataActor.shared.createPic(file.filename, data: file.data,
                                               inAlbumWithID: selectedAlbum?.id)
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = selectedItemCount
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }
}
