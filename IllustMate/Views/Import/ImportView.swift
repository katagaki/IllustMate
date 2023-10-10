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

    @AppStorage(wrappedValue: 0, "ImageSequence", store: .standard) var runningNumberForImageName: Int
    @AppStorage(wrappedValue: false, "DebugUseCoreDataThumbnail", store: defaults) var useCoreDataThumbnail: Bool

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
                        HStack(alignment: .center, spacing: 8.0) {
                            Text("Import.Album")
                            Spacer(minLength: 0)
                        }
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
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        Task {
            UIApplication.shared.isIdleTimerDisabled = true
            for selectedPhotoItem in selectedPhotoItems {
                if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                    let illustration = Illustration(
                        name: "PIC_\(String(format: "%04d", runningNumberForImageName))",
                        data: data)
                    if let selectedAlbum, albums.contains(selectedAlbum) {
                        selectedAlbum.addChildIllustration(illustration)
                    }
                    if useCoreDataThumbnail {
                        if let thumbnailData = UIImage(data: data)?.jpegThumbnail(of: 150.0) {
                            let thumbnail = Thumbnail(data: thumbnailData)
                            illustration.cachedThumbnail = thumbnail
                        }
                    } else {
                        if let thumbnailData = Illustration.makeThumbnail(data) {
                            FileManager.default.createFile(atPath: illustration.thumbnailPath(),
                                                           contents: thumbnailData)
                        }
                    }
                    modelContext.insert(illustration)
                    runningNumberForImageName += 1
                }
                progressAlertManager.incrementProgress()
            }
            UIApplication.shared.isIdleTimerDisabled = false
            importCompletedCount = selectedPhotoItems.count
            withAnimation(.easeOut.speed(2)) {
                selectedPhotoItems.removeAll()
                progressAlertManager.hide()
            } completion: {
                isImportCompleted = true
            }
        }
    }
}
