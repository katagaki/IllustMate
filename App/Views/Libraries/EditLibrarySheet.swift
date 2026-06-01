import SwiftUI

// swiftlint:disable:next type_body_length
struct EditLibrarySheet: View {

    @Environment(\.dismiss) var dismiss
    @Environment(ConcurrencyManager.self) var concurrency
    @Environment(ImageMigrationManager.self) var imageMigration
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var navigation: NavigationManager

    var library: PicLibrary
    var dismissAll: (() -> Void)?

    @State var editedName: String = ""
    @State var picCount: Int = 0
    @State var albumCount: Int = 0

    @State var isPickingBackupFolder: Bool = false
    @State var isBackupSheetPresented: Bool = false
    @State var backupFolderURL: URL?
    @State var isDuplicateCheckerPresented: Bool = false

    @State var isConfirmingClearCache: Bool = false
    @State var migrationIncomplete: Bool = false

    @State var libraryToDelete: PicLibrary?
    @State var deleteConfirmationCode: String = ""
    @State var expectedDeleteCode: String = ""

    @State var syncEnabled: Bool = false
    @State var iCloudAvailable: Bool = true
    @State var isShowingiCloudAlert: Bool = false
    @State var storageMode: StorageMode = .optimize
    @State var isConfirmingDownloadAll: Bool = false
    @State var isDownloadingAll: Bool = false
    @State var downloadProgress: Int = 0
    @State var downloadTotal: Int = 0

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
                    Toggle(isOn: Binding(
                        get: { syncEnabled },
                        set: { newValue in
                            if newValue && !iCloudAvailable {
                                isShowingiCloudAlert = true
                                return
                            }
                            syncEnabled = newValue
                            Task {
                                await LibrariesActor.shared.setSyncEnabled(newValue, forID: library.id)
                                await libraryManager.reloadList()
                                await SyncManager.shared.refresh()
                            }
                        }
                    )) {
                        Text("Sync.Title", tableName: "More")
                    }
                    .disabled(migrationIncomplete)
                    if syncEnabled {
                        Picker(selection: Binding(
                            get: { storageMode },
                            set: { newMode in
                                if newMode == .downloadAll {
                                    isConfirmingDownloadAll = true
                                } else {
                                    storageMode = newMode
                                    Task {
                                        await LibrariesActor.shared.setStorageMode(newMode.rawValue,
                                                                                   forID: library.id)
                                    }
                                }
                            }
                        )) {
                            Text("Sync.Storage.Optimize", tableName: "More").tag(StorageMode.optimize)
                            Text("Sync.Storage.DownloadAll", tableName: "More").tag(StorageMode.downloadAll)
                        } label: {
                            Text("Sync.Storage", tableName: "More")
                        }
                    }
                } footer: {
                    Text("Sync.Footer", tableName: "More")
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
                    if migrationIncomplete {
                        Button(String(localized: "Troubleshooting.Optimize", table: "More")) {
                            let libraryID = library.id
                            dismissAll?()
                            Task { await imageMigration.runIfNeeded(for: libraryID) }
                        }
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
            migrationIncomplete = await !DataActor.instance(for: library.id).isLibraryV2MigrationComplete()
            syncEnabled = await LibrariesActor.shared.isSyncEnabled(id: library.id)
            iCloudAvailable = await SyncManager.shared.canEnableSync()
            storageMode = StorageMode(rawValue: await LibrariesActor.shared.storageMode(forID: library.id))
                ?? .optimize
        }
        .alert(Text("Sync.iCloudRequired.Title", tableName: "More"),
               isPresented: $isShowingiCloudAlert) {
        } message: {
            Text("Sync.iCloudRequired.Message", tableName: "More")
        }
        .alert(Text("Sync.DownloadAll.Confirm.Title", tableName: "More"),
               isPresented: $isConfirmingDownloadAll) {
            Button("Shared.Yes") {
                storageMode = .downloadAll
                Task {
                    await LibrariesActor.shared.setStorageMode(StorageMode.downloadAll.rawValue,
                                                               forID: library.id)
                    await downloadAll()
                }
            }
            Button("Shared.No", role: .cancel) { }
        } message: {
            Text("Sync.DownloadAll.Confirm.Message", tableName: "More")
        }
        .sheet(isPresented: $isDownloadingAll) {
            StatusView(type: .inProgress,
                       title: .custom("Sync.Downloading", tableName: "More"),
                       currentCount: downloadProgress,
                       totalCount: downloadTotal)
                .phonePresentationDetents([.medium])
                .interactiveDismissDisabled()
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

    func downloadAll() async {
        let ids = await OriginalsManager.shared.picIDsNotMaterialized(in: library.id)
        guard !ids.isEmpty else { return }
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
            isDownloadingAll = true
            downloadProgress = 0
            downloadTotal = ids.count
        }
        for id in ids {
            _ = await OriginalsManager.shared.materializeOriginal(picID: id, in: library.id)
            await MainActor.run { downloadProgress += 1 }
        }
        await MainActor.run {
            isDownloadingAll = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
