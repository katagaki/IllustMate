//
//  ImporterView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ImporterView: View {

    @Environment(\.dismiss) var dismiss

    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State var selectedFileURLs: [URL] = []
    @State var selectedLoadedFiles: [(filename: String, data: Data)] = []
    @State var selectedAlbum: Album?

    @State var isImporting: Bool = false
    @State var isImportCompleted: Bool = false
    @State var importCurrentCount: Int = 0
    @State var importTotalCount: Int = 0
    @State var importCompletedCount: Int = 0

    @State var isFileImporterPresented: Bool = false
    @State var isFileImportSheetPresented: Bool = false

    @State var navigationPath = NavigationPath()

    var selectedItemCount: Int {
        selectedPhotoItems.count + selectedFileURLs.count + selectedLoadedFiles.count
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView(.vertical) {
                VStack(alignment: .center, spacing: 20.0) {
                    if !isImportCompleted {
                        if !isImporting {
                            VStack(alignment: .leading, spacing: 8.0) {
                                Text("Import.Section.FromPhotosApp", tableName: "Import")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)
                                Text("Import.Section.Photos.Description", tableName: "Import")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                                Group {
                                    PhotosPicker(selection: $selectedPhotoItems,
                                                 matching: .any(of: [.images, .videos]),
                                                 photoLibrary: .shared()) {
                                        Text("Import.SelectPhotos", tableName: "Import")
                                            .bold()
                                            .padding(4.0)
                                            .frame(maxWidth: .infinity)
                                    }
                                    Button {
                                        navigationPath.append("albumPicker")
                                    } label: {
                                        Text("Import.BrowseAlbums", tableName: "Import")
                                            .bold()
                                            .padding(4.0)
                                            .frame(maxWidth: .infinity)
                                    }
                                    Button {
                                        navigationPath.append("folderPicker")
                                    } label: {
                                        Text("Import.SelectFolder", tableName: "Import")
                                            .bold()
                                            .padding(4.0)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .buttonStyle(.glassProminent)
                                .buttonBorderShape(.capsule)
                                .disabled(isImporting)
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 8.0) {
                                Text("Import.Section.FromFilesApp", tableName: "Import")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)
                                Text("Import.Section.Files.Description", tableName: "Import")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                                Button {
                                    presentFileImporter()
                                } label: {
                                    Text("Import.SelectFromFiles", tableName: "Import")
                                        .bold()
                                        .padding(4.0)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glassProminent)
                                .buttonBorderShape(.capsule)
                                .disabled(isImporting)
                            }
                        } else {
                            StatusView(type: .inProgress, title: .importImporting,
                                       currentCount: importCurrentCount, totalCount: importTotalCount)
                        }
                    } else {
                        StatusView(type: .success, title: .importCompleted(count: importCompletedCount))
                    }
                }
                .padding(20.0)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: 16.0) {
                    if !isImportCompleted {
                        Text("Import.SelectedPhotos.\(selectedItemCount)", tableName: "Import")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            isImporting = true
                            importTotalCount = selectedItemCount
                            importPhotosAndFiles()
                        } label: {
                            Text("Import.StartImport", tableName: "Import")
                                .bold()
                                .padding(4.0)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.accent)
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.capsule)
                        .disabled(isImporting || selectedItemCount == 0)
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Text("Shared.OK")
                                .bold()
                                .padding(4.0)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.capsule)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20.0)
                .tint(.accent)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !isImporting {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("ViewTitle.Import")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { destination in
                if destination == "albumPicker" {
                    PhotosAlbumPickerView(selectedAlbum: selectedAlbum) {
                        dismiss()
                    }
                } else if destination == "folderPicker" {
                    PhotosFolderImportPickerView(selectedAlbum: selectedAlbum) {
                        dismiss()
                    }
                }
            }
            .modifier(FileImportModifier(
                isFileImporterPresented: $isFileImporterPresented,
                isFileImportSheetPresented: $isFileImportSheetPresented,
                onFilesImported: { files in selectedLoadedFiles = files }
            ))
        }
        .phonePresentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }

    func presentFileImporter() {
        #if targetEnvironment(macCatalyst)
        isFileImportSheetPresented = true
        #else
        isFileImporterPresented = true
        #endif
    }

    // swiftlint:disable:next function_body_length
    func importPhotosAndFiles() {
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            for selectedPhotoItem in selectedPhotoItems {
                var creationDate: Date?
                var filename: String?
                var isVideo = false
                var videoDuration: TimeInterval = 0

                if let identifier = selectedPhotoItem.itemIdentifier {
                    let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                    if let asset = result.firstObject {
                        creationDate = asset.creationDate
                        let resources = PHAssetResource.assetResources(for: asset)
                        filename = resources.first?.originalFilename
                        isVideo = asset.mediaType == .video
                        videoDuration = asset.duration
                    }
                }

                if isVideo {
                    await importVideoFromPhotosPicker(
                        selectedPhotoItem,
                        filename: filename ?? Pic.newVideoFilename(),
                        duration: videoDuration,
                        creationDate: creationDate
                    )
                } else if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                    await DataActor.shared.createPic(filename ?? Pic.newFilename(), data: data,
                                                   inAlbumWithID: selectedAlbum?.id,
                                                   dateAdded: creationDate)
                }
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            // Read file data synchronously while security-scoped access is valid,
            // then perform async database work separately
            var loadedImageFiles: [(filename: String, data: Data)] = []
            var loadedVideoFiles: [(filename: String, data: Data, duration: TimeInterval)] = []
            for fileURL in selectedFileURLs {
                let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing { fileURL.stopAccessingSecurityScopedResource() }
                }
                guard let data = try? Data(contentsOf: fileURL) else { continue }
                let uti = UTType(filenameExtension: fileURL.pathExtension)
                if uti?.conforms(to: .movie) == true || uti?.conforms(to: .video) == true {
                    let asset = AVURLAsset(url: fileURL)
                    let duration = (try? await asset.load(.duration))?.seconds ?? 0
                    loadedVideoFiles.append((filename: fileURL.lastPathComponent, data: data, duration: duration))
                } else if UIImage(data: data) != nil {
                    loadedImageFiles.append((filename: fileURL.lastPathComponent, data: data))
                }
            }
            for file in loadedImageFiles {
                await DataActor.shared.createPic(file.filename, data: file.data,
                                               inAlbumWithID: selectedAlbum?.id)
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            for file in loadedVideoFiles {
                let ext = (file.filename as NSString).pathExtension.lowercased()
                await DataActor.shared.createVideo(
                    file.filename, data: file.data, duration: file.duration,
                    fileExtension: ext.isEmpty ? "mov" : ext,
                    inAlbumWithID: selectedAlbum?.id
                )
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            // Import pre-loaded files (from Catalyst file import sheet)
            for file in selectedLoadedFiles {
                let uti = UTType(filenameExtension: (file.filename as NSString).pathExtension)
                if uti?.conforms(to: .movie) == true || uti?.conforms(to: .video) == true {
                    let ext = (file.filename as NSString).pathExtension.lowercased()
                    await DataActor.shared.createVideo(
                        file.filename, data: file.data, duration: 0,
                        fileExtension: ext.isEmpty ? "mov" : ext,
                        inAlbumWithID: selectedAlbum?.id
                    )
                } else {
                    await DataActor.shared.createPic(file.filename, data: file.data,
                                                   inAlbumWithID: selectedAlbum?.id)
                }
                await MainActor.run {
                    importCurrentCount += 1
                }
            }
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
                importCompletedCount = selectedItemCount
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                doWithAnimation {
                    isImportCompleted = true
                }
            }
        }
    }

    private func importVideoFromPhotosPicker(
        _ item: PhotosPickerItem,
        filename: String,
        duration: TimeInterval,
        creationDate: Date?
    ) async {
        guard let identifier = item.itemIdentifier else { return }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = result.firstObject else { return }

        let videoOptions = PHVideoRequestOptions()
        videoOptions.isNetworkAccessAllowed = true
        videoOptions.deliveryMode = .highQualityFormat

        let exportSession = await withCheckedContinuation {
            (continuation: CheckedContinuation<AVAssetExportSession?, Never>) in
            PHImageManager.default().requestExportSession(
                forVideo: asset,
                options: videoOptions,
                exportPreset: AVAssetExportPresetPassthrough
            ) { session, _ in
                continuation.resume(returning: session)
            }
        }

        guard let exportSession else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mov

        await exportSession.export()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        guard exportSession.status == .completed,
              let videoData = try? Data(contentsOf: tempURL) else { return }

        let fileExtension = (filename as NSString).pathExtension.isEmpty
            ? "mov" : (filename as NSString).pathExtension.lowercased()

        await DataActor.shared.createVideo(
            filename,
            data: videoData,
            duration: duration,
            fileExtension: fileExtension,
            inAlbumWithID: selectedAlbum?.id,
            dateAdded: creationDate
        )
    }
}
