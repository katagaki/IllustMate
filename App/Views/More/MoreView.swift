//
//  MoreView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI
import UniformTypeIdentifiers

struct MoreView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(AuthenticationManager.self) var auth
    @EnvironmentObject var navigation: NavigationManager

    @State var albumCount: Int = 0
    @State var picCount: Int = 0

    @State var isPickingBackupFolder: Bool = false
    @State var isBackupSheetPresented: Bool = false
    @State var backupFolderURL: URL?
    @State var isDuplicateCheckerPresented: Bool = false

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
                NavigationLink(String(localized: "Troubleshooting", table: "More"), value: ViewPath.moreTroubleshooting)
            } header: {
                Text("Advanced", tableName: "More")
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
            case .moreTroubleshooting: MoreTroubleshootingView()
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
}
