//
//  MoreTroubleshootingView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import Komponents
import SwiftUI
import UIKit

// swiftlint:disable type_body_length
struct MoreTroubleshootingView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(ConcurrencyManager.self) var concurrency
    @Environment(ProgressAlertManager.self) var progressAlertManager

    @State var isDeleteConfirming: Bool = false

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
                Button("More.Troubleshooting.CheckConsistency") {
                    Task {
                        await findDuplicates()
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
            for illustration in illustrations {
                if let data = await actor.imageData(forIllustrationWithID: illustration.id) {
                    let thumbnailData = Illustration.makeThumbnail(data)
                    await actor.updateThumbnail(forIllustrationWithID: illustration.id,
                                                thumbnailData: thumbnailData)
                }
                await MainActor.run {
                    progressAlertManager.incrementProgress()
                    if progressAlertManager.percentage >= 100 {
                        UIApplication.shared.isIdleTimerDisabled = false
                        progressAlertManager.hide()
                    }
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
            progressAlertManager.prepare("More.Troubleshooting.RestoreImageNames.Renaming",
                                         total: illustrations.count)
            progressAlertManager.show()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMddHHmmssSSSS"
            for illustration in illustrations {
                if illustration.name.starts(with: "PIC_") || illustration.name.starts(with: "ILLUST_") {
                    let newName = "PIC_" + dateFormatter.string(from: illustration.dateAdded)
                    await actor.renameIllustration(withID: illustration.id, to: newName)
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
        if let data = await actor.imageData(forIllustrationWithID: illustration.id),
           let image = UIImage(data: data) {
            var filename: URL = exportFolderURL.appending(component: illustration.name)
            let fileData: Data?
            if let pngData = image.pngData() {
                filename = filename.appendingPathExtension("png")
                fileData = pngData
            } else if let jpgData = image.jpegData(compressionQuality: 1.0) {
                filename = filename.appendingPathExtension("jpg")
                fileData = jpgData
            } else if let heicData = image.heicData() {
                filename = filename.appendingPathExtension("heic")
                fileData = heicData
            } else {
                fileData = data
            }
            try? fileData?.write(to: filename)
        }
        await MainActor.run {
            progressAlertManager.incrementProgress()
            if progressAlertManager.percentage >= 100 {
                progressAlertManager.hide()
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
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
                    albumsWithDuplicates += "\n\(illustration.containingAlbumID ?? "")"
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
