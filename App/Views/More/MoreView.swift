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

    @AppStorage("PhotosModeEnabled",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var isPhotosModeEnabled: Bool = false
    @AppStorage("AppLockEnabled",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var isAppLockEnabled: Bool = false
    @AppStorage("PhotosNestedAlbumsEnabled",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var isNestedAlbumsEnabled: Bool = false

    var body: some View {
        NavigationStack(path: $navigation.moreTabPath) {
            List {
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
                    Text("More.Stats")
                } footer: {
                    Text("More.Stats.Footer")
                }
                Section {
                    Toggle("More.PhotosMode", isOn: $isPhotosModeEnabled)
                } header: {
                    Text("More.PhotosMode.Header")
                } footer: {
                    Text("More.PhotosMode.Description")
                }
                Section {
                    Toggle("More.AppLock", isOn: $isAppLockEnabled)
                        .disabled(auth.biometryType == .none)
                } header: {
                    Text("More.Security")
                } footer: {
                    Text("More.AppLock.Description")
                }
                Section {
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
                    Button("More.Backup") {
                        isPickingBackupFolder = true
                    }
                } header: {
                    Text("More.Data")
                }
                Section {
                    NavigationLink("More.Troubleshooting", value: ViewPath.moreTroubleshooting)
                } header: {
                    Text("More.Advanced")
                }
                Section {
                    Toggle("More.Experiments.NestedAlbums", isOn: $isNestedAlbumsEnabled)
                        .disabled(!isPhotosModeEnabled)
                    Button("More.Experiments.NestedAlbums.CopyPrefix") {
                        UIPasteboard.general.string = "▶︎ "
                    }
                    .tint(.primary)
                    .disabled(!isNestedAlbumsEnabled)
                } header: {
                    Text("More.Experiments")
                } footer: {
                    Text("More.Experiments.NestedAlbums.Description")
                }
                Section {
                    Link(destination: URL(string: "https://github.com/katagaki/IllustMate")!) {
                        HStack {
                            Text(String(localized: "More.GitHub"))
                            Spacer()
                            Text("katagaki/IllustMate")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                    NavigationLink("More.Attributions", value: ViewPath.moreAttributions)
                }
            }
            .navigationTitle("ViewTitle.More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .moreDebug: MoreExperimentsView()
                case .moreTroubleshooting: MoreTroubleshootingView()
                case .moreAttributions: MoreLicensesView()
                default: Color.clear
                }
            }
        }
        .task {
            await loadCounts()
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
    }

    func loadCounts() async {
        let albums = await DataActor.shared.albumCount()
        let pics = await DataActor.shared.picCount()
        await MainActor.run {
            albumCount = albums
            picCount = pics
        }
    }
}
