//
//  MoreView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
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
            MoreList(repoName: "katagaki/IllustMate", viewPath: ViewPath.moreAttributions) {
                Section {
                    HStack(alignment: .top) {
                        VStack(spacing: 8.0) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                                .foregroundStyle(.secondary)
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
                            Image(systemName: "rectangle.stack.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
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
                    Toggle(isOn: $isPhotosModeEnabled) {
                        Label("More.PhotosMode", systemImage: "photo.on.rectangle.angled")
                    }
                } header: {
                    Text("More.PhotosMode.Header")
                } footer: {
                    Text("More.PhotosMode.Description")
                }
                Section {
                    Toggle(isOn: $isAppLockEnabled) {
                        Label("More.AppLock", systemImage: "lock.fill")
                    }
                    .disabled(auth.biometryType == .none)
                } header: {
                    Text("More.Security")
                } footer: {
                    Text("More.AppLock.Description")
                }
                Section {
                    Group {
                        Button {
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
                        } label: {
                            Label("Shared.OpenFilesApp", systemImage: "folder")
                        }
                        Button {
                            isPickingBackupFolder = true
                        } label: {
                            Label("More.Backup", systemImage: "externaldrive")
                        }
                    }
                    .tint(.primary)
                } header: {
                    Text("More.Data")
                }
                Section {
                    NavigationLink(value: ViewPath.moreTroubleshooting) {
                        Label("More.Troubleshooting", systemImage: "wrench.and.screwdriver")
                    }
                } header: {
                    Text("More.Advanced")
                }
                Section {
                    Toggle(isOn: $isNestedAlbumsEnabled) {
                        Text("More.Experiments.NestedAlbums")
                    }
                    .disabled(!isPhotosModeEnabled)
                    Button {
                        UIPasteboard.general.string = "▶︎ "
                    } label: {
                        Label("More.Experiments.NestedAlbums.CopyPrefix", systemImage: "doc.on.doc")
                    }
                    .tint(.primary)
                    .disabled(!isNestedAlbumsEnabled)
                } header: {
                    Text("More.Experiments")
                } footer: {
                    Text("More.Experiments.NestedAlbums.Description")
                }
            }
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
                case .moreAttributions: LicensesView(licenses: [
                    License(libraryName: "SQLite.swift", text:
"""
Copyright (c) 2014-2015 Stephen Celis (<stephen@stephencelis.com>)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
""")
                ])
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
