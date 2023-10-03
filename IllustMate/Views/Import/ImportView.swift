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

    @State var isImporting: Bool = false
    @State var currentProgress: Int = 0
    @State var total: Int = 0
    @State var percentage: Int = 0
    @AppStorage(wrappedValue: 0, "ImageSequence", store: .standard) var runningNumberForImageName: Int

    var body: some View {
        NavigationStack(path: $navigationManager.importerTabPath) {
            VStack(alignment: .center, spacing: 16.0) {
                PhotosPicker(selection: $selectedPhotoItems, matching: .images, photoLibrary: .shared()) {
                    HStack(alignment: .center, spacing: 4.0) {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18.0, height: 18.0)
                        Text("Import.SelectPhotos")
                            .bold()
                    }
                    .frame(minHeight: 24.0)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 99))
                .padding([.leading, .trailing], 20.0)
                Text(NSLocalizedString("Import.SelectedPhotos", comment: "")
                    .replacingOccurrences(of: "%1", with: String(selectedPhotoItems.count)))
                Button {
                    currentProgress = 0
                    total = selectedPhotoItems.count
                    percentage = 0
                    withAnimation(.easeOut.speed(2)) {
                        isImporting = true
                    }
                    Task {
                        var illustrations: [Illustration] = []
                        UIApplication.shared.isIdleTimerDisabled = true
                        for selectedPhotoItem in selectedPhotoItems {
                            debugPrint("Importing \(selectedPhotoItem.itemIdentifier ?? "Image") as illustration \(runningNumberForImageName)")
                            if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                                let illustration = Illustration(
                                    name: "ILLUST_\(String(format: "%04d", runningNumberForImageName))",
                                    data: data)
                                illustrations.append(illustration)
                                runningNumberForImageName += 1
                            }
                            DispatchQueue.main.async {
                                currentProgress += 1
                                percentage = Int((Float(currentProgress) / Float(total)) * 100.0)
                            }
                        }
                        for illustration in illustrations {
                            modelContext.insert(illustration)
                        }
                        UIApplication.shared.isIdleTimerDisabled = false
                        withAnimation(.easeOut.speed(2)) {
                            selectedPhotoItems.removeAll()
                            isImporting = false
                        }
                    }
                } label: {
                    HStack(alignment: .center, spacing: 4.0) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18.0, height: 18.0)
                        Text("Import.StartImport")
                            .bold()
                    }
                    .frame(minHeight: 24.0)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 99))
                .padding([.leading, .trailing], 20.0)
                .disabled(selectedPhotoItems.isEmpty)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if isImporting {
                    ProgressAlert(title: "Import.Importing", percentage: $percentage)
                }
            }
            .navigationTitle("ViewTitle.Import")
        }
    }
}
