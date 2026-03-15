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
    @State var selectedAlbum: Album?

    @State var isImporting: Bool = false
    @State var isImportCompleted: Bool = false
    @State var importCurrentCount: Int = 0
    @State var importTotalCount: Int = 0
    @State var importCompletedCount: Int = 0

    @State var isFileImporterPresented: Bool = false

    @State var navigationPath = NavigationPath()

    var selectedItemCount: Int {
        selectedPhotoItems.count + selectedFileURLs.count
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView(.vertical) {
                VStack(alignment: .center, spacing: 20.0) {
                    if !isImportCompleted {
                        if !isImporting {
                            VStack(alignment: .leading, spacing: 8.0) {
                                Text("Import.Section.Photos")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)
                                Text("Import.Section.Photos.Description")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                                Group {
                                    PhotosPicker(selection: $selectedPhotoItems,
                                                 matching: .images,
                                                 photoLibrary: .shared()) {
                                        Text("Import.SelectPhotos")
                                            .bold()
                                            .padding(4.0)
                                            .frame(maxWidth: .infinity)
                                    }
                                    Button {
                                        navigationPath.append("albumPicker")
                                    } label: {
                                        Text("Import.BrowseAlbums")
                                            .bold()
                                            .padding(4.0)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.capsule)
                                .disabled(isImporting)
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 8.0) {
                                Text("Import.Section.Files")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)
                                Text("Import.Section.Files.Description")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                                Button {
                                    isFileImporterPresented = true
                                } label: {
                                    Text("Import.SelectFromFiles")
                                        .bold()
                                        .padding(4.0)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.capsule)
                                .disabled(isImporting)
                            }
                        } else {
                            StatusView(type: .inProgress, title: "Import.Importing",
                                       currentCount: importCurrentCount, totalCount: importTotalCount)
                        }
                    } else {
                        StatusView(type: .success, title: "Import.Completed.Text.\(importCompletedCount)")
                    }
                }
                .padding(20.0)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: 16.0) {
                    if !isImportCompleted {
                        Text("Import.SelectedPhotos.\(selectedItemCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            isImporting = true
                            importTotalCount = selectedItemCount
                            importPhotosAndFiles()
                        } label: {
                            Text("Import.StartImport")
                                .bold()
                                .padding(4.0)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.green)
                        .buttonStyle(.borderedProminent)
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
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20.0)
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
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    selectedFileURLs = urls
                case .failure:
                    break
                }
            }
        }
        .phonePresentationDetents([.medium, .large])
        .interactiveDismissDisabled()
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
            for fileURL in selectedFileURLs {
                let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
                if let data = try? Data(contentsOf: fileURL),
                   UIImage(data: data) != nil {
                    let filename = fileURL.lastPathComponent
                    await DataActor.shared.createPic(filename, data: data,
                                                   inAlbumWithID: selectedAlbum?.id)
                }
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
