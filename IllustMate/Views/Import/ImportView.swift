//
//  ImportView.swift
//  IllustMate
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

    @Binding var isImporting: Bool
    @Binding var currentProgress: Int
    @Binding var total: Int
    @Binding var percentage: Int
    @AppStorage(wrappedValue: 0, "ImageSequence", store: .standard) var runningNumberForImageName: Int

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
                    Button {
                        currentProgress = 0
                        total = selectedPhotoItems.count
                        percentage = 0
                        withAnimation(.easeOut.speed(2)) {
                            isImporting = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            importPhotos()
                        }
                    } label: {
                        Text("Import.StartImport")
                    }
                    .disabled(selectedPhotoItems.isEmpty)
                } footer: {
                    Text("Import.SelectedPhotos.\(selectedPhotoItems.count)")
                    .font(.body)
                }
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
                        name: "ILLUST_\(String(format: "%04d", runningNumberForImageName))",
                        data: data)
                    if let selectedAlbum = selectedAlbum {
                        selectedAlbum.addChildIllustration(illustration)
                    }
                    modelContext.insert(illustration)
                    runningNumberForImageName += 1
                }
                DispatchQueue.main.async {
                    currentProgress += 1
                    percentage = Int((Float(currentProgress) / Float(total)) * 100.0)
                }
            }
            UIApplication.shared.isIdleTimerDisabled = false
            withAnimation(.easeOut.speed(2)) {
                selectedPhotoItems.removeAll()
                isImporting = false
            }
        }
    }
}
