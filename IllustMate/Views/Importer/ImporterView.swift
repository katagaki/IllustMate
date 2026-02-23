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

struct ImporterView: View {

    @Environment(\.dismiss) var dismiss

    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State var selectedAlbum: Album?

    @State var isImporting: Bool = false
    @State var isImportCompleted: Bool = false
    @State var importCurrentCount: Int = 0
    @State var importTotalCount: Int = 0
    @State var importCompletedCount: Int = 0

    @State var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView(.vertical) {
                VStack(alignment: .center, spacing: 16.0) {
                    if !isImportCompleted {
                        if !isImporting {
                            Text("Import.Instructions")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            PhotosPicker(selection: $selectedPhotoItems,
                                         matching: .images,
                                         photoLibrary: .shared()) {
                                Text("Import.SelectPhotos")
                                    .bold()
                                    .padding(4.0)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .disabled(isImporting)

                            Text("Import.BulkInstructions")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                navigationPath.append("albumPicker")
                            } label: {
                                Text("Import.BrowseAlbums")
                                    .bold()
                                    .padding(4.0)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .disabled(isImporting)
                        } else {
                            Text("Import.Importing")
                            ProgressView(value: Float(importCurrentCount), total: Float(importTotalCount))
                                .progressViewStyle(.linear)
                        }
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64.0, height: 64.0)
                            .symbolRenderingMode(.multicolor)
                        Text("Import.Completed.Text.\(importCompletedCount)")
                    }
                }
                .padding(20.0)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: 16.0) {
                    if !isImportCompleted {
                        Text("Import.SelectedPhotos.\(selectedPhotoItems.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            isImporting = true
                            importTotalCount = selectedPhotoItems.count
                            importPhotos()
                        } label: {
                            Text("Import.StartImport")
                                .bold()
                                .padding(4.0)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.green)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .disabled(isImporting || selectedPhotoItems.isEmpty)
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
                ToolbarItem(placement: .topBarLeading) {
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
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }

    func importPhotos() {
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            for selectedPhotoItem in selectedPhotoItems {
                if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                    var creationDate: Date? = nil
                    var filename: String? = nil
                    if let identifier = selectedPhotoItem.itemIdentifier {
                        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                        if let asset = result.firstObject {
                            creationDate = asset.creationDate
                            let resources = PHAssetResource.assetResources(for: asset)
                            filename = resources.first?.originalFilename
                        }
                    }
                    await actor.createIllustration(filename ?? Illustration.newFilename(), data: data,
                                                   inAlbumWithID: selectedAlbum?.id,
                                                   dateAdded: creationDate)
                }
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = selectedPhotoItems.count
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }
}
