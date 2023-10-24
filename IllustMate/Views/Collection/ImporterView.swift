//
//  ImporterView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import PhotosUI
import SwiftData
import SwiftUI

struct ImporterView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State var selectedAlbum: Album?

    @State var isImporting: Bool = false
    @State var isImportCompleted: Bool = false
    @State var importCurrentCount: Int = 0
    @State var importTotalCount: Int = 0
    @State var importCompletedCount: Int = 0

    let actor = DataActor(modelContainer: sharedModelContainer)

    @AppStorage(wrappedValue: 0, "ImageSequence", store: defaults) var runningNumberForImageName: Int

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .center, spacing: 16.0) {
                    if !isImportCompleted {
                        if !isImporting {
                            Text("Import.Instructions")
                            PhotosPicker(selection: $selectedPhotoItems, matching: .images, photoLibrary: .shared()) {
                                HStack(alignment: .center, spacing: 8.0) {
                                    Image("ListIcon.Photos")
                                        .resizable()
                                        .frame(width: 30.0, height: 30.0)
                                    Text("Import.SelectPhotos")
                                        .bold()
                                }
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
                        Button("Shared.Cancel", role: .cancel) {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("ViewTitle.Import")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    func importPhotos() {
        UIApplication.shared.isIdleTimerDisabled = true
        let selectedPhotoItems = selectedPhotoItems
        Task.detached(priority: .userInitiated) {
            let illustrationsToAdd = await withTaskGroup(of: Illustration?.self,
                                                         returning: [Illustration].self) { group in
                var illustrationsToAdd: [Illustration] = []
                for selectedPhotoItem in selectedPhotoItems {
                    group.addTask {
                        if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                            let illustration = Illustration(name: UUID().uuidString, data: data)
                            if let thumbnailData = UIImage(data: data)?.jpegThumbnail(of: 150.0) {
                                let thumbnail = Thumbnail(data: thumbnailData)
                                illustration.cachedThumbnail = thumbnail
                            }
                            importCurrentCount += 1
                            return illustration
                        } else {
                            importCurrentCount += 1
                            return nil
                        }
                    }
                }
                for await result in group {
                    if let result {
                        result.name = "PIC_\(String(format: "%04d", runningNumberForImageName))"
                        runningNumberForImageName += 1
                        illustrationsToAdd.append(result)
                    }
                }
                return illustrationsToAdd
            }
            for illustration in illustrationsToAdd {
                await actor.createIllustration(illustration)
                if let selectedAlbum {
                    await actor.addIllustration(illustration,
                                                toAlbumWithIdentifier: selectedAlbum.persistentModelID)
                }
            }
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = selectedPhotoItems.count
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }
}
