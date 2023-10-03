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
                    Button {
                        currentProgress = 0
                        total = selectedPhotoItems.count
                        percentage = 0
                        withAnimation(.easeOut.speed(2)) {
                            isImporting = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            Task {
                                UIApplication.shared.isIdleTimerDisabled = true
                                for selectedPhotoItem in selectedPhotoItems {
                                    if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                                        let illustration = Illustration(
                                            name: "ILLUST_\(String(format: "%04d", runningNumberForImageName))",
                                            data: data)
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
                    } label: {
                        Text("Import.StartImport")
                    }
                    .disabled(selectedPhotoItems.isEmpty)
                } footer: {
                    Text(NSLocalizedString("Import.SelectedPhotos", comment: "")
                        .replacingOccurrences(of: "%1", with: String(selectedPhotoItems.count)))
                    .font(.body)
                }
            }
            .navigationTitle("ViewTitle.Import")
        }
    }
}
