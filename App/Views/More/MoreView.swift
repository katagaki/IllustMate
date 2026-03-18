//
//  MoreView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MoreView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(AuthenticationManager.self) var auth
    @Environment(ConcurrencyManager.self) var concurrency
    @EnvironmentObject var navigation: NavigationManager

    @State var albumCount: Int = 0
    @State var picCount: Int = 0

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

    @AppStorage("PhotosModeEnabled", store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate"))
    var isPhotosModeEnabled: Bool = false
    @AppStorage("AppLockEnabled", store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate"))
    var isAppLockEnabled: Bool = false
    @AppStorage("PhotosNestedAlbumsEnabled", store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate"))
    var isNestedAlbumsEnabled: Bool = false
    @AppStorage("ShareSheetOpenSearch", store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate"))
    var openSearchWhenSharing: Bool = false
    @AppStorage("ShareSheetShowAnimation", store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate"))
    var showAnimationWhenSaving: Bool = true
    @AppStorage("ShareSheetQuickImport",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var quickImport: Bool = false
    @AppStorage("ShareSheetDefaultAlbum",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var defaultAlbumID: String = ""

    @State var allAlbums: [Album] = []

    private var listContent: some View {
        List {
            Section {
                Toggle(String(localized: "PhotosMode", table: "More"), isOn: $isPhotosModeEnabled)
                if isPhotosModeEnabled {
                    Toggle(String(localized: "Experiments.NestedAlbums", table: "More"), isOn: $isNestedAlbumsEnabled)
                    Button(String(localized: "Experiments.NestedAlbums.CopyPrefix", table: "More")) {
                        UIPasteboard.general.string = "▶︎ "
                    }
                    .tint(.primary)
                    .disabled(!isNestedAlbumsEnabled)
                }
            } header: {
                Text("PhotosMode.Header", tableName: "More")
            } footer: {
                if isPhotosModeEnabled {
                    Text("Experiments.NestedAlbums.Description", tableName: "More")
                } else {
                    Text("PhotosMode.Description", tableName: "More")
                }
            }
            Section {
                Toggle(String(localized: "AppLock", table: "More"), isOn: $isAppLockEnabled)
                    .disabled(auth.biometryType == .none)
            } header: {
                Text("Security", tableName: "More")
            } footer: {
                Text("AppLock.Description", tableName: "More")
            }
            Section {
                Toggle(String(localized: "ShareSheet.OpenSearch", table: "More"), isOn: $openSearchWhenSharing)
                Toggle(String(localized: "ShareSheet.ShowAnimation", table: "More"), isOn: $showAnimationWhenSaving)
                Toggle(String(localized: "ShareSheet.QuickImport", table: "More"), isOn: $quickImport)
                if quickImport {
                    Picker(String(localized: "ShareSheet.DefaultAlbum", table: "More"),
                           selection: $defaultAlbumID) {
                        Text("ShareSheet.DefaultAlbum.None", tableName: "More")
                            .tag("")
                        Divider()
                        Text("ShareSheet.DefaultAlbum.Collection", tableName: "More")
                            .tag("__collection__")
                        Divider()
                        ForEach(allAlbums) { album in
                            Text(album.name).tag(album.id)
                        }
                    }
                }
            } header: {
                Text("ShareSheet", tableName: "More")
            } footer: {
                if quickImport && !defaultAlbumID.isEmpty {
                    if defaultAlbumID == "__collection__" {
                        Text("ShareSheet.DefaultAlbum.Collection.Description", tableName: "More")
                    } else {
                        Text("ShareSheet.DefaultAlbum.Description", tableName: "More")
                    }
                } else {
                    Text("ShareSheet.QuickImport.Description", tableName: "More")
                }
            }
            WebServerView()
            Section {
                Button(String(localized: "DuplicateChecker", table: "More")) {
                    isDuplicateCheckerPresented = true
                }
                Button(String(localized: "Backup", table: "More")) {
                    isPickingBackupFolder = true
                }
                Button("Shared.OpenFilesApp") {
                    let documentsUrl = FileManager.default.urls(
                        for: .documentDirectory, in: .userDomainMask
                    ).first!
#if targetEnvironment(macCatalyst)
                    UIApplication.shared.open(documentsUrl)
#else
                    if let sharedUrl = URL(string: "shareddocuments://\(documentsUrl.path)") {
                        if UIApplication.shared.canOpenURL(sharedUrl) {
                            UIApplication.shared.open(sharedUrl)
                        }
                    }
#endif
                }
            } header: {
                Text("Tools", tableName: "More")
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
            } header: {
                Text("Stats", tableName: "More")
            } footer: {
                Text("Stats.Footer", tableName: "More")
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
            } footer: {
                Text("Troubleshooting.DataManagement.Description", tableName: "More")
            }
            Section {
                Link(destination: URL(string: "https://github.com/katagaki/IllustMate")!) {
                    HStack {
                        Text(String(localized: "GitHub", table: "More"))
                        Spacer()
                        Text("katagaki/IllustMate")
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
                NavigationLink(String(localized: "Attributions", table: "More"), value: ViewPath.moreAttributions)
            }
        }
        .tint(.accent)
        .navigationTitle("ViewTitle.More")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ViewPath.self) { viewPath in
            switch viewPath {
            case .moreDebug: MoreExperimentsView()
            case .moreAttributions: MoreLicensesView()
            default: Color.clear
            }
        }
    }

    var body: some View {
        NavigationStack(path: $navigation.moreTabPath) {
            listContent
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
        }
        .task {
            await loadCounts()
            await loadAlbums()
        }
        .onChange(of: navigation.dataVersion) { _, _ in
            dismiss()
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
                MoreBackupView(destinationURL: backupFolderURL)
            }
        }
        .sheet(isPresented: $isDuplicateCheckerPresented) {
            DuplicateScanView(scanScope: .entireCollection)
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
        .sheet(isPresented: $isRebuildingThumbnails) {
            StatusView(type: .inProgress, title: .troubleshootingRebuildingThumbnails,
                       currentCount: rebuildProgress, totalCount: rebuildTotal)
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
        let albums = await DataActor.shared.albumCount()
        let pics = await DataActor.shared.picCount()
        await MainActor.run {
            albumCount = albums
            picCount = pics
        }
    }

    func loadAlbums() async {
        do {
            let albums = try await DataActor.shared.albumsWithCounts(sortedBy: .nameAscending)
            await MainActor.run {
                allAlbums = albums
            }
        } catch {
            debugPrint(error.localizedDescription)
        }
    }

    func rebuildThumbnails() async {
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
            isRebuildingThumbnails = true
            rebuildProgress = 0
            rebuildTotal = 0
        }
        do {
            let pics = try await DataActor.shared.pics()
            await MainActor.run {
                rebuildTotal = pics.count
            }
            await DataActor.shared.deleteAllThumbnails()
            for pic in pics {
                if let data = await DataActor.shared.imageData(forPicWithID: pic.id) {
                    let thumbnailData = Pic.makeThumbnail(data)
                    await DataActor.shared.updateThumbnail(forPicWithID: pic.id,
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
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
            isFreeingUpSpace = true
        }
        await DataActor.shared.vacuum()
        await MainActor.run {
            isFreeingUpSpace = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
