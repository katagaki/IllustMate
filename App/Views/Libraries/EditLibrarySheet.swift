//
//  EditLibrarySheet.swift
//  PicMate
//
//  Created by Claude on 2026/03/18.
//

import SwiftUI

struct EditLibrarySheet: View {

    @Environment(\.dismiss) var dismiss
    @Environment(ConcurrencyManager.self) var concurrency
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var navigation: NavigationManager

    var library: PicLibrary

    @State var editedName: String = ""
    @State var picCount: Int = 0
    @State var albumCount: Int = 0

    @State var isPickingBackupFolder: Bool = false
    @State var isBackupSheetPresented: Bool = false
    @State var backupFolderURL: URL?
    @State var isDuplicateCheckerPresented: Bool = false

    @State var isConfirmingRebuildThumbnails: Bool = false
    @State var isRebuildingThumbnails: Bool = false
    @State var rebuildProgress: Int = 0
    @State var rebuildTotal: Int = 0
    @State var isConfirmingFreeUpSpace: Bool = false
    @State var isFreeingUpSpace: Bool = false
    @State var isConfirmingClearCache: Bool = false

    @State var libraryToDelete: PicLibrary?
    @State var deleteConfirmationCode: String = ""
    @State var expectedDeleteCode: String = ""

    var body: some View {
        NavigationStack {
            List {
                if library.id != libraryManager.currentLibrary.id {
                    Section {
                        Button(String(localized: "Libraries.SetActive", table: "Libraries")) {
                            withAnimation(.smooth.speed(2.0)) {
                                libraryManager.switchLibrary(to: library)
                                navigation.signalDataDeleted()
                            }
                        }
                    }
                }
                if !library.isDefault {
                    Section {
                        TextField(String(localized: "Libraries.New.Placeholder", table: "Libraries"),
                                  text: $editedName)
                    } header: {
                        Text("Libraries.Edit.Name", tableName: "Libraries")
                    }
                }
                Section {
                    Button(String(localized: "DuplicateChecker", table: "More")) {
                        isDuplicateCheckerPresented = true
                    }
                    Button(String(localized: "Backup", table: "More")) {
                        isPickingBackupFolder = true
                    }
                } header: {
                    Text("Tools", tableName: "More")
                }
                Section {
                    Button(String(localized: "Troubleshooting.RebuildThumbnails", table: "More")) {
                        isConfirmingRebuildThumbnails = true
                    }
                    Button(String(localized: "Troubleshooting.FreeUpSpace", table: "More")) {
                        isConfirmingFreeUpSpace = true
                    }
                    Button(String(localized: "Troubleshooting.ClearCache", table: "More")) {
                        isConfirmingClearCache = true
                    }
                } header: {
                    Text("Troubleshooting.DataManagement", tableName: "More")
                }
                Section {
                    HStack(alignment: .top) {
                        VStack(spacing: 8.0) {
                            Text("\(picCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Shared.Pics")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        VStack(spacing: 8.0) {
                            Text("\(albumCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Shared.Albums")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                if !library.isDefault {
                    Section {
                        Button(role: .destructive) {
                            expectedDeleteCode = String(format: "%06d", Int.random(in: 0...999_999))
                            deleteConfirmationCode = ""
                            libraryToDelete = library
                        } label: {
                            Text("Libraries.Delete.Title", tableName: "Libraries")
                        }
                    }
                }
            }
            .tint(.accent)
            .navigationTitle(String(localized: "Libraries.Edit.Title", table: "Libraries"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty && trimmed != library.name {
                            Task {
                                await libraryManager.renameLibrary(library, to: trimmed)
                            }
                        }
                        dismiss()
                    }
                }
            }
        }
        .phonePresentationDetents([.medium, .large])
        .interactiveDismissDisabled()
        .onAppear {
            editedName = library.isDefault ? "" : library.name
        }
        .task {
            await loadCounts()
        }
        .fileImporter(isPresented: $isPickingBackupFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                backupFolderURL = url
                isBackupSheetPresented = true
            case .failure(let error):
                debugPrint(error.localizedDescription)
            }
        }
        .sheet(isPresented: $isBackupSheetPresented) {
            if let backupFolderURL {
                MoreBackupView(destinationURL: backupFolderURL,
                              collectionID: library.id,
                              libraryName: library.isDefault
                                  ? String(localized: "Collection.Default", table: "Libraries")
                                  : library.name)
            }
        }
        .sheet(isPresented: $isDuplicateCheckerPresented) {
            DuplicateScanView(scanScope: .entireCollection, collectionID: library.id)
        }
        .alert(Text("Troubleshooting.RebuildThumbnails.Confirm.Title", tableName: "More"),
               isPresented: $isConfirmingRebuildThumbnails) {
            Button("Shared.Yes", role: .destructive) {
                Task { await rebuildThumbnails() }
            }
            Button("Shared.No", role: .cancel) { }
        } message: {
            Text("Troubleshooting.RebuildThumbnails.Confirm.Message", tableName: "More")
        }
        .alert(Text("Troubleshooting.FreeUpSpace.Confirm.Title", tableName: "More"),
               isPresented: $isConfirmingFreeUpSpace) {
            Button("Shared.Yes", role: .destructive) {
                Task { await freeUpSpace() }
            }
            Button("Shared.No", role: .cancel) { }
        } message: {
            Text("Troubleshooting.FreeUpSpace.Confirm.Message", tableName: "More")
        }
        .alert(Text("Troubleshooting.ClearCache.Confirm.Title", tableName: "More"),
               isPresented: $isConfirmingClearCache) {
            Button("Shared.Yes", role: .destructive) {
                Task {
                    await HashActor.shared.deleteAllHashes()
                    await PColorActor.shared.deleteAllColors()
                    await CoverCacheActor.shared.deleteAllCovers()
                }
            }
            Button("Shared.No", role: .cancel) { }
        } message: {
            Text("Troubleshooting.ClearCache.Confirm.Message", tableName: "More")
        }
        .alert(String(localized: "Libraries.Delete.Title", table: "Libraries"),
               isPresented: Binding(
                get: { libraryToDelete != nil },
                set: { if !$0 { libraryToDelete = nil } }
               )) {
            TextField("", text: $deleteConfirmationCode, prompt: Text(expectedDeleteCode))
                .keyboardType(.numberPad)
            Button(String(localized: "Shared.Delete", table: "Libraries"), role: .destructive) {
                guard let library = libraryToDelete,
                      deleteConfirmationCode == expectedDeleteCode else { return }
                let wasCurrentLibrary = library.id == libraryManager.currentLibrary.id
                Task {
                    await libraryManager.deleteLibrary(library)
                    if wasCurrentLibrary {
                        navigation.signalDataDeleted()
                    }
                }
                libraryToDelete = nil
                dismiss()
            }
            .disabled(deleteConfirmationCode != expectedDeleteCode)
            Button("Shared.Cancel", role: .cancel) {
                libraryToDelete = nil
            }
        } message: {
            Text("Libraries.Delete.Message \(expectedDeleteCode)", tableName: "Libraries")
        }
        .sheet(isPresented: $isRebuildingThumbnails) {
            StatusView(
                type: .inProgress,
                title: .troubleshootingRebuildingThumbnails,
                currentCount: rebuildProgress,
                totalCount: rebuildTotal
            )
            .phonePresentationDetents([.medium])
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isFreeingUpSpace) {
            StatusView(type: .inProgress, title: .troubleshootingFreeingUpSpace)
                .phonePresentationDetents([.medium])
                .interactiveDismissDisabled()
        }
    }

    func loadCounts() async {
        let dataActor = DataActor(collectionID: library.id)
        let albums = await dataActor.albumCount()
        let pics = await dataActor.picCount()
        await MainActor.run {
            albumCount = albums
            picCount = pics
        }
    }

    func rebuildThumbnails() async {
        let dataActor = DataActor(collectionID: library.id)
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
            isRebuildingThumbnails = true
            rebuildProgress = 0
            rebuildTotal = 0
        }
        do {
            let pics = try await dataActor.pics()
            await MainActor.run {
                rebuildTotal = pics.count
            }
            await dataActor.deleteAllThumbnails()
            for pic in pics {
                if let data = await dataActor.imageData(forPicWithID: pic.id) {
                    let thumbnailData = Pic.makeThumbnail(data)
                    await dataActor.updateThumbnail(forPicWithID: pic.id,
                                                    thumbnailData: thumbnailData)
                }
                await MainActor.run {
                    rebuildProgress += 1
                }
            }
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
                isRebuildingThumbnails = false
            }
        } catch {
            debugPrint(error.localizedDescription)
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
                isRebuildingThumbnails = false
            }
        }
    }

    func freeUpSpace() async {
        let dataActor = DataActor(collectionID: library.id)
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
            isFreeingUpSpace = true
        }
        await dataActor.vacuum()
        await MainActor.run {
            isFreeingUpSpace = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
