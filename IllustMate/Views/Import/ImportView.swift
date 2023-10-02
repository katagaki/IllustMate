//
//  ImportView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import PhotosUI
import SwiftUI

struct ImportView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @State var selectedPhotoItems: [PhotosPickerItem] = []

    @State var isImporting: Bool = false
    @State var currentProgress: Int = 0
    @State var total: Int = 0
    @State var percentage: Int = 0

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
                        for selectedPhotoItem in selectedPhotoItems {
                            debugPrint(selectedPhotoItem.itemIdentifier ?? "Image")
                            if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                                // TODO: Generate illustration name
                                let illustration = Illustration(name: selectedPhotoItem.itemIdentifier ?? "",
                                                                   data: data)
                                illustrations.append(illustration)
                            }
                            DispatchQueue.main.async {
                                currentProgress += 1
                                percentage = Int((Float(currentProgress) / Float(total)) * 100.0)
                            }
                        }
                        for illustration in illustrations {
                            modelContext.insert(illustration)
                        }
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
