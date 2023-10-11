//
//  MoreFileManagementView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftData
import SwiftUI

struct MoreFileManagementView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @Query var illustrations: [Illustration]
    @Query var albums: [Album]
    @Query var thumbnails: [Thumbnail]
    @State var orphans: [String] = []

    @Binding var progressAlertManager: ProgressAlertManager

    @AppStorage(wrappedValue: true, "DebugUseCoreDataThumbnail", store: defaults) var useCoreDataThumbnail: Bool

    var body: some View {
        List {
            Section {
                HStack(alignment: .center, spacing: 8.0) {
                    Text("Shared.Albums")
                    Spacer(minLength: 0)
                    Text("\(albums.count)")
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .center, spacing: 8.0) {
                    Text("Shared.Illustrations")
                    Spacer(minLength: 0)
                    Text("\(illustrations.count)")
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .center, spacing: 8.0) {
                    Text("Shared.Thumbnails")
                    Spacer(minLength: 0)
                    Text("\(thumbnails.count)")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button("More.DataManagement.ScanForOrphans") {
                    scanForOrphans()
                }
                Button("More.DataManagement.ViewOrphans") {
                    showOrphans()
                }
            }
            Section {
                Button("More.DataManagement.RebuildThumbnails") {
                    rebuildThumbnails()
                }
                Button("More.DataManagement.RebuildThumbnails.MissingOnly") {
                    rebuildMissingThumbnails()
                }
            }
            Section {
                Button("More.DataManagement.RedownloadThumbnails") {
                    redownloadThumbnails()
                }
                Button("More.DataManagement.RedownloadIllustrations") {
                    redownloadIllustrations()
                }
            }
        }
        .navigationTitle("ViewTitle.DataManagement")
        .navigationBarTitleDisplayMode(.inline)
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

    func scanForOrphans() {
        UIApplication.shared.isIdleTimerDisabled = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var fetchDescriptor = FetchDescriptor<Illustration>()
                fetchDescriptor.propertiesToFetch = [\.id]
                let illustrations = try modelContext.fetch(fetchDescriptor)
                progressAlertManager.prepare("More.DataManagement.ScanForOrphans.Scanning")
                withAnimation(.easeOut.speed(2)) {
                    progressAlertManager.show()
                }
                let filesToCheck = try FileManager.default
                    .contentsOfDirectory(at: illustrationsFolder, includingPropertiesForKeys: nil)
                orphans.removeAll()
                progressAlertManager.prepare("More.DataManagement.ScanForOrphans.Scanning",
                                             total: filesToCheck.count)
                for file in filesToCheck {
                    if !illustrations.contains(where: { file.lastPathComponent.contains($0.id) }) {
                        orphans.append(file.lastPathComponent)
                    }
                    progressAlertManager.incrementProgress()
                }
                progressAlertManager.prepare("More.DataManagement.ScanForOrphans.Moving", total: orphans.count)
                orphans.forEach { orphan in
                    try? FileManager.default.moveItem(
                        at: illustrationsFolder.appendingPathComponent(orphan),
                        to: orphansFolder.appendingPathComponent(orphan))
                    progressAlertManager.incrementProgress()
                }
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = false
                    withAnimation(.easeOut.speed(2)) {
                        progressAlertManager.hide()
                    } completion: {
                        if !orphans.isEmpty {
                            navigationManager.push(ViewPath.moreOrphans(orphans: orphans), for: .more)
                        }
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    func rebuildThumbnails() {
        UIApplication.shared.isIdleTimerDisabled = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let illustrations = try modelContext.fetch(FetchDescriptor<Illustration>())
                progressAlertManager.prepare("More.DataManagement.RebuildThumbnails.Rebuilding",
                                             total: illustrations.count)
                withAnimation(.easeOut.speed(2)) {
                    progressAlertManager.show()
                } completion: {
                    modelContext.autosaveEnabled = false
                    if useCoreDataThumbnail {
                        try? modelContext.delete(model: Thumbnail.self, includeSubclasses: true)
                    } else {
                        try? modelContext.delete(model: Thumbnail.self, includeSubclasses: true)
                        try? FileManager.default.removeItem(at: thumbnailsFolder)
                        try? FileManager.default.createDirectory(at: thumbnailsFolder,
                                                                 withIntermediateDirectories: false)
                    }
                    DispatchQueue.global(qos: .background).async {
                        illustrations.forEach { illustration in
                            autoreleasepool {
                                illustration.generateThumbnail()
                                try? modelContext.save()
                                progressAlertManager.incrementProgress()
                            }
                        }
                        DispatchQueue.main.async {
                            modelContext.autosaveEnabled = true
                            UIApplication.shared.isIdleTimerDisabled = false
                            withAnimation(.easeOut.speed(2)) {
                                progressAlertManager.hide()
                            }
                        }
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
                modelContext.autosaveEnabled = true
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    func rebuildMissingThumbnails() {
        UIApplication.shared.isIdleTimerDisabled = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let illustrations = try modelContext.fetch(FetchDescriptor<Illustration>(
                    predicate: #Predicate { $0.cachedThumbnail == nil }
                ))
                progressAlertManager.prepare("More.DataManagement.RebuildThumbnails.Rebuilding",
                                             total: illustrations.count)
                withAnimation(.easeOut.speed(2)) {
                    progressAlertManager.show()
                } completion: {
                    modelContext.autosaveEnabled = false
                    DispatchQueue.global(qos: .background).async {
                        illustrations.forEach { illustration in
                            autoreleasepool {
                                illustration.generateThumbnail()
                                try? modelContext.save()
                                progressAlertManager.incrementProgress()
                            }
                        }
                        DispatchQueue.main.async {
                            try? modelContext.save()
                            modelContext.autosaveEnabled = true
                            UIApplication.shared.isIdleTimerDisabled = false
                            withAnimation(.easeOut.speed(2)) {
                                progressAlertManager.hide()
                            }
                        }
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
                modelContext.autosaveEnabled = true
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    func redownloadThumbnails() {
        UIApplication.shared.isIdleTimerDisabled = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let illustrations = try modelContext.fetch(FetchDescriptor<Illustration>())
                progressAlertManager.prepare("More.DataManagement.RedownloadThumbnails.Redownloading",
                                             total: illustrations.count)
                withAnimation(.easeOut.speed(2)) {
                    progressAlertManager.show()
                }
                for illustration in illustrations {
                    do {
                        try FileManager.default.startDownloadingUbiquitousItem(
                            at: URL(filePath: illustration.thumbnailPath()))
                        var isDownloaded: Bool = false
                        while !isDownloaded {
                            if FileManager.default.fileExists(atPath: illustration.thumbnailPath()) {
                                isDownloaded = true
                            }
                        }
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                    progressAlertManager.incrementProgress()
                }
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = false
                    withAnimation(.easeOut.speed(2)) {
                        progressAlertManager.hide()
                    } completion: {
                        // TODO: Show an alert that the downloads may take some time to complete
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    func redownloadIllustrations() {
        UIApplication.shared.isIdleTimerDisabled = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let illustrations = try modelContext.fetch(FetchDescriptor<Illustration>())
                progressAlertManager.prepare("More.DataManagement.RedownloadIllustrations.Redownloading",
                                             total: illustrations.count)
                withAnimation(.easeOut.speed(2)) {
                    progressAlertManager.show()
                }
                for illustration in illustrations {
                    do {
                        try FileManager.default.startDownloadingUbiquitousItem(
                            at: URL(filePath: illustration.illustrationPath()))
                        var isDownloaded: Bool = false
                        while !isDownloaded {
                            if FileManager.default.fileExists(atPath: illustration.illustrationPath()) {
                                isDownloaded = true
                            }
                        }
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                    progressAlertManager.incrementProgress()
                }
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = false
                    withAnimation(.easeOut.speed(2)) {
                        progressAlertManager.hide()
                    } completion: {
                        // TODO: Show an alert that the downloads may take some time to complete
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
}
