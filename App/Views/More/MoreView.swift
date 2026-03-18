//
//  MoreView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI
import UIKit

struct MoreView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(AuthenticationManager.self) var auth
    @EnvironmentObject var navigation: NavigationManager

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
            await loadAlbums()
        }
        .onChange(of: navigation.dataVersion) { _, _ in
            dismiss()
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
