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
    @Environment(ProgressAlertManager.self) var progressAlertManager

    @State var selectedPhotoItems: [PhotosPickerItem] = []

    @State var selectedAlbum: Album?

    @State var isImportCompleted: Bool = false
    @State var importCompletedCount: Int = 0

    @AppStorage(wrappedValue: 0, "ImageSequence", store: defaults) var runningNumberForImageName: Int

    var body: some View {
        VStack(alignment: .center, spacing: 16.0) {
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
            Spacer()
            Text("Import.SelectedPhotos.\(selectedPhotoItems.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                progressAlertManager.prepare("Import.Importing",
                                             total: selectedPhotoItems.count)
                withAnimation(.easeOut.speed(2)) {
                    progressAlertManager.show()
                } completion: {
                    importPhotos()
                }
            } label: {
                Text("Import.StartImport")
                    .bold()
                    .padding(4.0)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(selectedPhotoItems.isEmpty)
        }
        .padding(20.0)
        .alert("Alert.ImportCompleted.Title", isPresented: $isImportCompleted) {
            Button("Shared.OK") {
                dismiss()
            }
        } message: {
            Text("Alert.ImportCompleted.Text.\(importCompletedCount)")
        }
        .navigationTitle("ViewTitle.Import")
        .navigationBarTitleDisplayMode(.inline)
    }

    func importPhotos() {
        UIApplication.shared.isIdleTimerDisabled = true
        let selectedPhotoItems = selectedPhotoItems
        let selectedAlbum = selectedAlbum
        // TODO: Importer stops working after run once
        Task.detached(priority: .high) {
            let illustrationsToAdd = await withTaskGroup(of: Illustration?.self,
                                                         returning: [Illustration].self) { group in
                var illustrationsToAdd: [Illustration] = []
                for selectedPhotoItem in selectedPhotoItems {
                    group.addTask {
                        var runningNumberForImageName = runningNumberForImageName
                        if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                            let illustration = Illustration(
                                name: "PIC_\(String(format: "%04d", runningNumberForImageName))",
                                data: data)
                            if let thumbnailData = UIImage(data: data)?.jpegThumbnail(of: 150.0) {
                                let thumbnail = Thumbnail(data: thumbnailData)
                                illustration.cachedThumbnail = thumbnail
                            }
                            runningNumberForImageName += 1
                            return illustration
                        } else {
                            return nil
                        }
                    }
                }
                for await result in group {
                    progressAlertManager.incrementProgress()
                    if let result {
                        illustrationsToAdd.append(result)
                    }
                }
                return illustrationsToAdd
            }
            await MainActor.run { [illustrationsToAdd] in
                illustrationsToAdd.forEach { illustration in
                    modelContext.insert(illustration)
                }
                if let selectedAlbum {
                    selectedAlbum.addChildIllustrations(illustrationsToAdd)
                }
                self.runningNumberForImageName += selectedPhotoItems.count
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = selectedPhotoItems.count
                withAnimation(.easeOut.speed(2)) {
                    self.selectedPhotoItems.removeAll()
                    progressAlertManager.hide()
                } completion: {
                    isImportCompleted = true
                }
            }
        }
    }
}
