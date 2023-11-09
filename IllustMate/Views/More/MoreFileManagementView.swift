//
//  MoreFileManagementView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/11.
//

import SwiftData
import SwiftUI

struct MoreFileManagementView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(ProgressAlertManager.self) var progressAlertManager

    let queue: OperationQueue
    @State var showOrphanedFilesViewFlag: Bool = false

    init() {
        queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 8
    }

    var body: some View {
        List {
            Section {
                Button("More.FileManagement.Export") {
                    Task {
                        await exportData()
                    }
                }
            }
            Section {
                Button("More.FileManagement.ScanAndMoveOrphans") {
                    Task {
                        await scanAndMoveOrphans()
                    }
                }
                Button("More.FileManagement.ShowOrphanedFiles") {
                    showOrphans()
                }
            }
            Section {
                Button("More.FileManagement.RedownloadIllustrations") {
                    Task {
                        await redownloadIllustrations()
                    }
                }
            }
        }
        .onChange(of: showOrphanedFilesViewFlag) { _, _ in
            showOrphans()
        }
        .navigationTitle("ViewTitle.FileManagement")
        .navigationBarTitleDisplayMode(.inline)
    }

    func exportData() async {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let albums = try await actor.albums(sortedBy: .nameAscending)
            let illustrationsWithNoParentAlbum = try await actor.illustrations(in: nil, order: .reverse)
            let illustrationCount = await actor.illustrationCount()
            progressAlertManager.prepare("More.FileManagement.Exporting", total: illustrationCount)
            progressAlertManager.show()
            if !directoryExistsAtPath(exportsFolder) {
                try? FileManager.default.createDirectory(at: exportsFolder, withIntermediateDirectories: false)
            } else {
                try? FileManager.default.removeItem(at: exportsFolder)
                try? FileManager.default.createDirectory(at: exportsFolder, withIntermediateDirectories: false)
            }
            for illustration in illustrationsWithNoParentAlbum {
                await exportIllustration(illustration: illustration, to: exportsFolder)
            }
            for album in albums {
                await exportAlbum(album: album, to: exportsFolder)
            }
        } catch {
            debugPrint(error.localizedDescription)
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func exportAlbum(album: Album, to exportFolderURL: URL) async {
        let albumFolderURL = exportFolderURL.appending(path: album.name)
        if !directoryExistsAtPath(albumFolderURL) {
            try? FileManager.default.createDirectory(at: albumFolderURL, withIntermediateDirectories: false)
        }
        do {
            let childIllustrations = try await actor.illustrations(in: album, order: .reverse)
            for childIllustration in childIllustrations {
                await exportIllustration(illustration: childIllustration, to: albumFolderURL)
            }
        } catch {
            debugPrint(error.localizedDescription)
        }
        do {
            let childAlbums = try await actor.albums(in: album, sortedBy: .nameAscending)
            for childAlbum in childAlbums {
                await exportAlbum(album: childAlbum, to: albumFolderURL)
            }
        } catch {
            debugPrint(error.localizedDescription)
        }
    }

    func exportIllustration(illustration: Illustration, to exportFolderURL: URL) async {
        let intent = NSFileAccessIntent.readingIntent(with: URL(filePath: illustration.illustrationPath()))
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(with: [intent], queue: queue) { error in
            if let error {
                debugPrint(error.localizedDescription)
            } else {
                var filename: URL = exportFolderURL.appending(component: illustration.name)
                if let image = UIImage(contentsOfFile: illustration.illustrationPath()) {
                    if image.pngData() != nil {
                        filename = filename.appendingPathExtension("png")
                    } else if image.jpegData(compressionQuality: 0.1) != nil {
                        filename = filename.appendingPathExtension("jpg")
                    } else if image.heicData() != nil {
                        filename = filename.appendingPathExtension("heic")
                    }
                    try? FileManager.default.copyItem(atPath: illustration.illustrationPath(),
                                                      toPath: filename.path(percentEncoded: false))
                }
                Task {
                    await MainActor.run {
                        progressAlertManager.incrementProgress()
                        if progressAlertManager.percentage == 100 {
                            progressAlertManager.hide()
                        }
                    }
                }
            }
        }
    }

    func scanAndMoveOrphans() async {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let illustrations = try await actor.illustrations()
            let filesToCheck = try FileManager.default.contentsOfDirectory(at: illustrationsFolder,
                                                                           includingPropertiesForKeys: nil)
            progressAlertManager.prepare("More.FileManagement.Orphans.Scanning", total: filesToCheck.count)
            progressAlertManager.show()
            let orphans: [String] = await withTaskGroup(of: String?.self, returning: [String].self) { group in
                var orphans: [String] = []
                for file in filesToCheck {
                    group.addTask {
                        if !illustrations.contains(where: { file.lastPathComponent.contains($0.id) }) {
                            await MainActor.run {
                                progressAlertManager.incrementProgress()
                            }
                            return file.lastPathComponent
                        }
                        await MainActor.run {
                            progressAlertManager.incrementProgress()
                        }
                        return nil
                    }
                }
                for await result in group {
                    if let result {
                        orphans.append(result)
                    }
                }
                return orphans
            }
            progressAlertManager.prepare("More.FileManagement.Orphans.Moving", total: orphans.count)
            for orphan in orphans {
                try? FileManager.default.moveItem(
                    at: illustrationsFolder.appendingPathComponent(orphan),
                    to: orphansFolder.appendingPathComponent(orphan))
                await MainActor.run {
                    progressAlertManager.incrementProgress()
                }
            }
            progressAlertManager.hide()
        } catch {
            debugPrint(error.localizedDescription)
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func showOrphans() {
        let orphanFiles = try? FileManager.default.contentsOfDirectory(
            atPath: orphansFolder.path(percentEncoded: false))
        if let orphanFiles {
            var orphans: [String] = []
            for orphanFile in orphanFiles {
                var orphanFileName = URL(filePath: orphanFile).lastPathComponent
                if orphanFileName != ".DS_Store" {
                    if orphanFileName.starts(with: ".") {
                        orphanFileName = orphanFileName.trimmingCharacters(in: .init(charactersIn: "."))
                    }
                    if orphanFileName.hasSuffix(".icloud") {
                        orphanFileName = String(orphanFileName.prefix(36))
                    }
                    orphans.append(orphanFileName)
                }
            }
            navigationManager.push(ViewPath.moreOrphans(orphans: orphans), for: .more)
        }
    }

    func redownloadIllustrations() async {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let illustrations = try await actor.illustrations()
            progressAlertManager.prepare("More.FileManagement.RedownloadIllustrations.Redownloading",
                                         total: illustrations.count)
            progressAlertManager.show()
            for illustration in illustrations {
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(
                        at: URL(filePath: illustration.illustrationPath()))
                } catch {
                    debugPrint(error.localizedDescription)
                }
                await MainActor.run {
                    progressAlertManager.incrementProgress()
                }
            }
            UIApplication.shared.isIdleTimerDisabled = false
            progressAlertManager.hide {
                // TODO: Show an alert that the downloads may take some time to complete
            }
        } catch {
            debugPrint(error.localizedDescription)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
