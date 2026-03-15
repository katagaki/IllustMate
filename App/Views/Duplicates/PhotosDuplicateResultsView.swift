//
//  PhotosDuplicateResultsView.swift
//  PicMate
//
//  Created on 2026/03/15.
//

import Komponents
import Photos
import SwiftUI

struct PhotosDuplicateResultsView: View {

    var scanManager: PhotosDuplicateScanManager

    @State var selectedForDeletion: [UUID: Set<String>] = [:]
    @State var isConfirmingDeleteAll: Bool = false

    var allSelectedIDs: Set<String> {
        selectedForDeletion.values.reduce(into: Set<String>()) { $0.formUnion($1) }
    }

    var groupsWithSelections: Int {
        selectedForDeletion.values.filter { !$0.isEmpty }.count
    }

    var body: some View {
        if scanManager.duplicateGroups.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "Duplicates.NoDuplicatesFound", table: "Photos"), systemImage: "checkmark.circle")
            } description: {
                Text("Duplicates.NoDuplicatesFound.Message", tableName: "Photos")
            }
        } else {
            List {
                ForEach(scanManager.duplicateGroups) { group in
                    PhotosDuplicateGroupSection(
                        group: group,
                        selectedForDeletion: Binding(
                            get: { selectedForDeletion[group.id] ?? [] },
                            set: { selectedForDeletion[group.id] = $0 }
                        )
                    ) { deletedIDs in
                        scanManager.removeAssets(withIDs: deletedIDs)
                        selectedForDeletion[group.id] = nil
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .toolbar {
                if groupsWithSelections > 1 {
                    ToolbarItem(placement: .bottomBar) {
                        Button(String(localized: "Duplicates.DeleteAllSelected.\(allSelectedIDs.count)", table: "Photos"),
                               role: .destructive) {
                            isConfirmingDeleteAll = true
                        }
                    }
                }
            }
            .alert(
                "Shared.DeleteConfirmation.Photo.\(allSelectedIDs.count)",
                isPresented: $isConfirmingDeleteAll
            ) {
                Button("Shared.Yes", role: .destructive) {
                    Task {
                        let idsToDelete = allSelectedIDs
                        let deleted = await deletePhotosAssets(withIdentifiers: Array(idsToDelete))
                        guard deleted else { return }
                        for assetID in idsToDelete {
                            await HashActor.shared.deleteHash(forPicWithID: assetID)
                        }
                        await MainActor.run {
                            withAnimation(.smooth.speed(2.0)) {
                                scanManager.removeAssets(withIDs: idsToDelete)
                                selectedForDeletion = [:]
                            }
                        }
                    }
                }
                Button("Shared.No", role: .cancel) {}
            }
        }
    }
}

// MARK: - Group Section

struct PhotosDuplicateGroupSection: View {

    let group: PhotosDuplicateGroup
    @Binding var selectedForDeletion: Set<String>
    var onDelete: (Set<String>) -> Void

    @State var isConfirmingDelete: Bool = false

    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12.0) {
                    ForEach(group.assets, id: \.localIdentifier) { asset in
                        PhotosDuplicateDetailCard(
                            asset: asset,
                            isSelectedForDeletion: selectedForDeletion.contains(asset.localIdentifier)
                        ) {
                            withAnimation(.smooth.speed(2.0)) {
                                if selectedForDeletion.contains(asset.localIdentifier) {
                                    selectedForDeletion.remove(asset.localIdentifier)
                                } else {
                                    if selectedForDeletion.count < group.assets.count - 1 {
                                        selectedForDeletion.insert(asset.localIdentifier)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4.0)
                .padding(.horizontal, 18.0)
            }
            .listRowInsets(EdgeInsets(top: 14.0, leading: 0, bottom: 14.0, trailing: 0))
            if !selectedForDeletion.isEmpty {
                Button(String(localized: "Duplicates.DeleteSelected.\(selectedForDeletion.count)", table: "Photos"),
                       role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        } header: {
            Text("Duplicates.GroupCount.\(group.assets.count)", tableName: "Photos")
        }
        .alert(
            "Shared.DeleteConfirmation.Photo.\(selectedForDeletion.count)",
            isPresented: $isConfirmingDelete
        ) {
            Button("Shared.Yes", role: .destructive) {
                Task {
                    let idsToDelete = selectedForDeletion
                    let deleted = await deletePhotosAssets(withIdentifiers: Array(idsToDelete))
                    guard deleted else { return }
                    for assetID in idsToDelete {
                        await HashActor.shared.deleteHash(forPicWithID: assetID)
                    }
                    await MainActor.run {
                        withAnimation(.smooth.speed(2.0)) {
                            onDelete(idsToDelete)
                        }
                    }
                    selectedForDeletion = []
                }
            }
            Button("Shared.No", role: .cancel) {}
        }
    }
}

// MARK: - Photos Deletion Helper

nonisolated func deletePhotosAssets(withIdentifiers identifiers: [String]) async -> Bool {
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
    do {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
        return true
    } catch {
        debugPrint("Failed to delete photos assets: \(error)")
        return false
    }
}

// MARK: - Detail Card

struct PhotosDuplicateDetailCard: View {

    let asset: PHAsset
    let isSelectedForDeletion: Bool
    let onToggle: () -> Void

    @State private var thumbnail: UIImage?
    @State private var fileSize: String?

    var body: some View {
        Button { onToggle() } label: {
            VStack(spacing: 6.0) {
                ZStack {
                    Rectangle()
                        .fill(.primary.opacity(0.05))
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: 120.0, height: 120.0)
                .clipShape(.rect(cornerRadius: 10.0))
                .overlay(alignment: .bottomTrailing) {
                    SelectionOverlay(isSelectedForDeletion)
                }

                VStack(spacing: 2.0) {
                    Text("\(asset.pixelWidth) × \(asset.pixelHeight)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let fileSize {
                        Text(fileSize)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let creationDate = asset.creationDate {
                        Text(creationDate, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 120.0)
        }
        .buttonStyle(.plain)
        .task {
            loadThumbnail()
            loadFileSize()
        }
    }

    private func loadThumbnail() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        PHCachingImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 240, height: 240),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result {
                DispatchQueue.main.async {
                    self.thumbnail = result
                }
            }
        }
    }

    private func loadFileSize() {
        let resources = PHAssetResource.assetResources(for: asset)
        if let resource = resources.first,
           let sizeValue = resource.value(forKey: "fileSize") as? Int64, sizeValue > 0 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            DispatchQueue.main.async {
                self.fileSize = formatter.string(fromByteCount: sizeValue)
            }
        }
    }
}
