//
//  PhotosFolderPickerView.swift
//  PicMate
//
//  Created on 2026/03/08.
//

import Photos
import SwiftUI

struct PhotosFolderPickerView: View {

    @Environment(PhotosManager.self) var photosManager

    let album: PHAssetCollection
    var onMoved: () -> Void

    @State private var folders: [PHCollectionList] = []
    @State private var hasFetched: Bool = false

    var body: some View {
        List {
            if hasFetched {
                if folders.isEmpty {
                    Text("Photos.NoFolders", tableName: "Photos")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(folders, id: \.localIdentifier) { folder in
                        Button {
                            Task {
                                do {
                                    try await photosManager.moveAlbum(album, into: folder)
                                    await MainActor.run {
                                        onMoved()
                                    }
                                } catch {
                                    debugPrint(error.localizedDescription)
                                }
                            }
                        } label: {
                            Label(folder.localizedTitle ?? String(localized: "Import.Albums.Untitled", table: "Import"),
                                  systemImage: "folder")
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if !hasFetched {
                fetchFolders()
            }
        }
    }

    private func fetchFolders() {
        var collected: [PHCollectionList] = []
        let result = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        result.enumerateObjects { collection, _, _ in
            if let folder = collection as? PHCollectionList {
                collected.append(folder)
            }
        }
        folders = collected.sorted {
            ($0.localizedTitle ?? "").localizedCaseInsensitiveCompare($1.localizedTitle ?? "") == .orderedAscending
        }
        hasFetched = true
    }
}
