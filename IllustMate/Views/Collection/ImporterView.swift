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

    @Environment(\.dismiss) var dismiss

    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State var selectedAlbum: Album?

    @State var isImporting: Bool = false
    @State var isImportCompleted: Bool = false
    @State var importCurrentCount: Int = 0
    @State var importTotalCount: Int = 0
    @State var importCompletedCount: Int = 0

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
        Task {
            await withDiscardingTaskGroup { group in
                for selectedPhotoItem in selectedPhotoItems {
                    group.addTask {
                        if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                            let illustration = Illustration(name: Illustration.newFilename(), data: data)
                            await actor.createIllustration(illustration)
                            if let selectedAlbum {
                                await actor.addIllustration(illustration,
                                                            toAlbumWithIdentifier: selectedAlbum.persistentModelID)
                            }
                        }
                        await MainActor.run {
                            importCurrentCount += 1
                        }
                    }
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
