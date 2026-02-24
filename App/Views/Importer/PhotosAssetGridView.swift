//
//  PhotosAssetGridView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/02/22.
//

import Photos
import SwiftUI

struct PhotosAssetGridView: View {

    let collection: PHAssetCollection
    var selectedAlbum: Album?
    var onDismiss: () -> Void

    @State private var assets: [PHAsset] = []
    @State private var selectedAssets: Set<String> = []

    @State private var isImporting: Bool = false
    @State private var isImportCompleted: Bool = false
    @State private var importCurrentCount: Int = 0
    @State private var importTotalCount: Int = 0
    @State private var importCompletedCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            if isImportCompleted {
                StatusView(type: .success, title: "Import.Completed.Text.\(importCompletedCount)")
                Button {
                    onDismiss()
                } label: {
                    Text("Shared.OK")
                        .bold()
                        .padding(4.0)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(20.0)
            } else if isImporting {
                StatusView(type: .inProgress, title: "Import.Importing",
                           currentCount: importCurrentCount, totalCount: importTotalCount)
            } else {
                ScrollView {
                    let columns = [GridItem(.adaptive(minimum: 80), spacing: 2)]
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            PhotoGridCell(
                                asset: asset,
                                isSelected: selectedAssets.contains(asset.localIdentifier)
                            ) {
                                toggleAsset(asset)
                            }
                        }
                    }
                }

                // Bottom bar
                VStack(alignment: .center, spacing: 16.0) {
                    Text("Import.SelectedPhotos.\(selectedAssets.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        startImport()
                    } label: {
                        Text("Import.StartImport")
                            .bold()
                            .padding(4.0)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.green)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(selectedAssets.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .padding(20.0)
            }
        }
        .navigationTitle(collection.localizedTitle ?? String(localized: "Import.Albums.Untitled"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isImporting || isImportCompleted)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !isImporting && !isImportCompleted {
                    Button {
                        if selectedAssets.count == assets.count {
                            selectedAssets.removeAll()
                        } else {
                            selectedAssets = Set(assets.map { $0.localIdentifier })
                        }
                    } label: {
                        Text(selectedAssets.count == assets.count ?
                             "Import.DeselectAll" : "Import.SelectAll")
                    }
                }
            }
        }
        .interactiveDismissDisabled(isImporting)
        .onAppear {
            if assets.isEmpty {
                fetchAssets()
            }
        }
    }

    // MARK: - Data

    private func fetchAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            fetched.append(asset)
        }
        assets = fetched
        // Select all by default for bulk import convenience
        selectedAssets = Set(fetched.map { $0.localIdentifier })
    }

    private func toggleAsset(_ asset: PHAsset) {
        if selectedAssets.contains(asset.localIdentifier) {
            selectedAssets.remove(asset.localIdentifier)
        } else {
            selectedAssets.insert(asset.localIdentifier)
        }
    }

    private func startImport() {
        let assetsToImport = assets.filter { selectedAssets.contains($0.localIdentifier) }
        isImporting = true
        importTotalCount = assetsToImport.count
        importCurrentCount = 0

        UIApplication.shared.isIdleTimerDisabled = true

        Task {
            let imageManager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = false
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.isNetworkAccessAllowed = true

            for asset in assetsToImport {
                let data = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                    imageManager.requestImageDataAndOrientation(
                        for: asset, options: requestOptions
                    ) { data, _, _, _ in
                        continuation.resume(returning: data)
                    }
                }

                if let data {
                    let resources = PHAssetResource.assetResources(for: asset)
                    let filename = resources.first?.originalFilename ?? Pic.newFilename()
                    await dataActor.createPic(
                        filename, data: data,
                        inAlbumWithID: selectedAlbum?.id,
                        dateAdded: asset.creationDate
                    )
                }

                await MainActor.run {
                    importCurrentCount += 1
                }
            }

            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = assetsToImport.count
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }
}
