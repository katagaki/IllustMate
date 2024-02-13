//
//  MoreTroubleshootingView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import Komponents
import SwiftData
import SwiftUI

// swiftlint:disable type_body_length
struct MoreTroubleshootingView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(ConcurrencyManager.self) var concurrency
    @Environment(ProgressAlertManager.self) var progressAlertManager

    @Query var thumbnails: [Thumbnail]

    @State var isDeleteConfirming: Bool = false

    let queue: OperationQueue

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
            } header: {
                ListSectionHeader(text: "More.Troubleshooting.Portability")
                    .font(.body)
            }
            Section {
                Button("More.Troubleshooting.RebuildThumbnails") {
                    Task {
                        await rebuildThumbnails()
                    }
                }
                Button("More.Troubleshooting.UnorphanThumbnails") {
                    Task {
                        await removeOrphanedThumbnails()
                    }
                }
                Button("More.Troubleshooting.RestoreImageNames") {
                    Task {
                        await rebuildImageNames()
                    }
                }
            } header: {
                ListSectionHeader(text: "More.Troubleshooting.DataManagement")
                    .font(.body)
            }
            Section {
                Button("More.Troubleshooting.RedownloadIllustrations") {
                    Task {
                        await redownloadIllustrations()
                    }
                }
                Button("More.Troubleshooting.CheckConsistency") {
                    Task {
                        await scanAndMoveOrphans()
                        await findDuplicates()
                        await findReorphans()
                    }
                }
                Button("More.Troubleshooting.ShowOrphanedFiles") {
                    showOrphans()
                }
            } header: {
                ListSectionHeader(text: "More.Troubleshooting.FileManagement")
                    .font(.body)
            }
            Section {
                Button("More.Troubleshooting.DeleteAll", role: .destructive) {
                    isDeleteConfirming = true
                }
            }
        }
        .alert("Alert.DeleteAll.Title", isPresented: $isDeleteConfirming) {
            Button("Shared.Yes", role: .destructive) {
                Task {
                    await deleteData()
                    deleteContents(of: illustrationsFolder)
                    deleteContents(of: orphansFolder)
                    navigationManager.popAll()
                }
            }
            Button("Shared.No", role: .cancel) { }
        } message: {
            Text("Alert.DeleteAll.Text")
        }
        .navigationTitle("ViewTitle.Troubleshooting")
        .navigationBarTitleDisplayMode(.inline)
    }

    func exportData() async {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let albums = try await actor.albums(in: nil, sortedBy: .nameAscending)
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
    }

    func rebuildThumbnails() async {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let illustrations = try await actor.illustrations()
            progressAlertManager.prepare("More.Troubleshooting.RebuildThumbnails.Rebuilding",
                                         total: illustrations.count)
            await actor.deleteAllThumbnails()
            progressAlertManager.show()
            let coordinator = NSFileCoordinator()
            for illustration in illustrations {
                let url = URL(filePath: illustration.illustrationPath())
                let intent = NSFileAccessIntent.readingIntent(with: url)
                coordinator.coordinate(with: [intent], queue: concurrency.queue) { error in
                    if let error {
                        debugPrint(error.localizedDescription)
                        Task {
                            await MainActor.run {
                                progressAlertManager.incrementProgress()
                            }
                        }
                    } else {
                        Task {
                            illustration.generateThumbnail()
                            await MainActor.run {
                                progressAlertManager.incrementProgress()
                                if progressAlertManager.percentage >= 100 {
                                    Task {
                                        await actor.save()
                                    }
                                    UIApplication.shared.isIdleTimerDisabled = false
                                    progressAlertManager.hide()
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            debugPrint(error.localizedDescription)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    func removeOrphanedThumbnails() async {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let thumbnails = try await actor.thumbnails()
            progressAlertManager.prepare("More.Troubleshooting.UnorphanThumbnails.Unorphaning", total: thumbnails.count)
            progressAlertManager.show()
            for thumbnail in thumbnails {
                if thumbnail.illustration == nil {
                    await actor.deleteThumbnail(withID: thumbnail.persistentModelID)
                }
                await MainActor.run {
                    progressAlertManager.incrementProgress()
                }
            }
            UIApplication.shared.isIdleTimerDisabled = false
            progressAlertManager.hide()
        } catch {
            debugPrint(error.localizedDescription)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    func rebuildImageNames() async {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let illustrations = try await actor.illustrations()
            progressAlertManager.prepare("More.Troubleshooting.RestoreImageNames.Renaming", total: thumbnails.count)
            progressAlertManager.show()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMddHHmmssSSSS"
            for illustration in illustrations {
                if illustration.name.starts(with: "PIC_") || illustration.name.starts(with: "ILLUST_") {
                    illustration.name = "PIC_" + dateFormatter.string(from: illustration.dateAdded)
                }
                await MainActor.run {
                    progressAlertManager.incrementProgress()
                }
            }
            UIApplication.shared.isIdleTimerDisabled = false
            progressAlertManager.hide()
        } catch {
            debugPrint(error.localizedDescription)
            UIApplication.shared.isIdleTimerDisabled = false
        }
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
                            UIApplication.shared.isIdleTimerDisabled = false
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
            progressAlertManager.prepare("More.Troubleshooting.Orphans.Scanning", total: filesToCheck.count)
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
            progressAlertManager.prepare("More.Troubleshooting.Orphans.Moving", total: orphans.count)
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

    func findDuplicates() async {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let illustrations = try await actor.illustrations()
            var albumsWithDuplicates = ""
            progressAlertManager.prepare("More.Troubleshooting.Duplicates.Scanning", total: illustrations.count)
            progressAlertManager.show()
            for illustration in illustrations {
                let illustrationsFound = illustrations.filter({ $0.id == illustration.id })
                if illustrationsFound.count > 1 {
                    albumsWithDuplicates += "\n\(illustration.containingAlbum?.name ?? "")"
                }
                await MainActor.run {
                    progressAlertManager.incrementProgress()
                }
            }
            if albumsWithDuplicates != "" {
                progressAlertManager.title = "More.Troubleshooting.Duplicates.Found.\(albumsWithDuplicates)"
                try? await Task.sleep(nanoseconds: 3000000000)
                await MainActor.run {
                    progressAlertManager.hide()
                }
            } else {
                progressAlertManager.hide()
            }
        } catch {
            debugPrint(error.localizedDescription)
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func findReorphans() async {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let illustrations = try await actor.illustrations()
            var albumsWithReorphans = ""
            progressAlertManager.prepare("More.Troubleshooting.Reorphans.Scanning", total: illustrations.count)
            progressAlertManager.show()
            for illustration in illustrations {
                if !FileManager.default.fileExists(atPath: illustration.illustrationPath()) {
                    albumsWithReorphans += "\n\(illustration.containingAlbum?.name ?? "")"
                }
                await MainActor.run {
                    progressAlertManager.incrementProgress()
                }
            }
            if albumsWithReorphans != "" {
                progressAlertManager.title = "More.Troubleshooting.Reorphans.Found.\(albumsWithReorphans)"
                try? await Task.sleep(nanoseconds: 3000000000)
                await MainActor.run {
                    progressAlertManager.hide()
                }
            } else {
                progressAlertManager.hide()
            }
        } catch {
            debugPrint(error.localizedDescription)
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func redownloadIllustrations() async {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let illustrations = try await actor.illustrations()
            progressAlertManager.prepare("More.Troubleshooting.RedownloadIllustrations.Redownloading",
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

    func deleteData() async {
        await actor.deleteAll()
    }

    func deleteContents(of url: URL?) {
        if let url, let fileURLs = try? FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) {
            for fileURL in fileURLs {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
// swiftlint:enable type_body_length
