//
//  ImportView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import PhotosUI
import SwiftData
import SwiftUI

struct ImportView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @State var selectedPhotoItems: [PhotosPickerItem] = []

    @Query(sort: \Album.name, animation: .snappy.speed(2)) var albums: [Album]
    @State var selectedAlbum: Album?

    @Binding var progressAlertManager: ProgressAlertManager

    @State var isImportCompleted: Bool = false
    @State var importCompletedCount: Int = 0

    @AppStorage(wrappedValue: 0, "ImageSequence", store: defaults) var runningNumberForImageName: Int

    var body: some View {
        NavigationStack(path: $navigationManager.importerTabPath) {
            List {
                Section {
                    Text("Import.Instructions")
                        .padding([.top, .bottom], 2.0)
                        .alignmentGuide(.listRowSeparatorLeading, computeValue: { _ in
                            0
                        })
                    PhotosPicker(selection: $selectedPhotoItems, matching: .images, photoLibrary: .shared()) {
                        ListRow(image: "ListIcon.Photos", title: "Import.SelectPhotos")
                    }
                } header: {
                    Text(verbatim: " ")
                }
                Section {
                    Picker(selection: $selectedAlbum) {
                        Text("Import.Album.None")
                            .tag(nil as Album?)
                        ForEach(albums, id: \.id) { album in
                            AlbumRow(album: album)
                                .tag(album as Album?)
                        }
                    } label: {
                        Text("Import.Album")
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    ListSectionHeader(text: "Import.SelectAlbum")
                        .font(.body)
                }
                Section {
                    Button("Import.StartImport") {
                        progressAlertManager.prepare("Import.Importing",
                                                     total: selectedPhotoItems.count)
                        withAnimation(.easeOut.speed(2)) {
                            progressAlertManager.show()
                        } completion: {
                            importPhotos()
                        }
                    }
                    .disabled(selectedPhotoItems.isEmpty)
                } footer: {
                    Text("Import.SelectedPhotos.\(selectedPhotoItems.count)")
                    .font(.body)
                }
            }
            .alert("Alert.ImportCompleted.Title", isPresented: $isImportCompleted) {
                Button("Shared.OK") { }
            } message: {
                Text("Alert.ImportCompleted.Text.\(importCompletedCount)")
            }
            .navigationTitle("ViewTitle.Import")
        }
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
                        var runningNumberForImageName = await runningNumberForImageName
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
                    await progressAlertManager.incrementProgress()
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
                if let selectedAlbum, albums.contains(selectedAlbum) {
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
