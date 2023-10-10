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

    @State var orphans: [String] = []

    @Binding var progressAlertManager: ProgressAlertManager

    @AppStorage(wrappedValue: false, "DebugUseCoreDataThumbnail", store: defaults) var useCoreDataThumbnail: Bool

    var body: some View {
        List {
            Section {
                Button("More.Files.ScanForOrphans") {
                    scanForOrphans()
                }
                Button("More.Files.ViewOrphans") {
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
            }
            Section {
                Button("More.Files.RebuildThumbnails") {
                    rebuildThumbnails()
                }
                Button("More.Files.RedownloadThumbnails") {
                    redownloadThumbnails()
                }
            }
            Section {
                Button("More.Files.RedownloadIllustrations") {
                    redownloadIllustrations()
                }
            }
        }
        .navigationTitle("ViewTitle.Files")
        .navigationBarTitleDisplayMode(.inline)
    }

    func scanForOrphans() {
        UIApplication.shared.isIdleTimerDisabled = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var fetchDescriptor = FetchDescriptor<Illustration>()
                fetchDescriptor.propertiesToFetch = [\.id]
                let illustrations = try modelContext.fetch(fetchDescriptor)
                progressAlertManager.prepare("More.Files.ScanForOrphans.Scanning")
                withAnimation(.easeOut.speed(2)) {
                    progressAlertManager.show()
                }
                let filesToCheck = try FileManager.default
                    .contentsOfDirectory(at: illustrationsFolder, includingPropertiesForKeys: nil)
                orphans.removeAll()
                progressAlertManager.prepare("More.Files.ScanForOrphans.Scanning",
                                             total: filesToCheck.count)
                for file in filesToCheck {
                    if !illustrations.contains(where: { file.lastPathComponent.contains($0.id) }) {
                        orphans.append(file.lastPathComponent)
                    }
                    progressAlertManager.incrementProgress()
                }
                progressAlertManager.prepare("More.Files.ScanForOrphans.Moving", total: orphans.count)
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
        do {
            let illustrations = try modelContext.fetch(FetchDescriptor<Illustration>())
            progressAlertManager.prepare("More.Files.RebuildThumbnails.Rebuilding",
                                         total: illustrations.count)
            withAnimation(.easeOut.speed(2)) {
                progressAlertManager.show()
            }
            try FileManager.default.removeItem(at: thumbnailsFolder)
            try FileManager.default.createDirectory(at: thumbnailsFolder,
                                                    withIntermediateDirectories: false)
            Task {
                let useCoreDataThumbnail = useCoreDataThumbnail
                await withDiscardingTaskGroup { group in
                    for illustration in illustrations {
                        group.addTask {
                            illustration.generateThumbnail()
                            DispatchQueue.main.async {
                                progressAlertManager.incrementProgress()
                            }
                        }
                    }
                }
                await MainActor.run {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
                withAnimation(.easeOut.speed(2)) {
                    progressAlertManager.hide()
                }
            }
        } catch {
            debugPrint(error.localizedDescription)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    func redownloadThumbnails() {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let illustrations = try modelContext.fetch(FetchDescriptor<Illustration>())
            progressAlertManager.prepare("More.Files.RedownloadThumbnails.Redownloading",
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
                DispatchQueue.main.async {
                    progressAlertManager.incrementProgress()
                }
            }
            UIApplication.shared.isIdleTimerDisabled = false
            withAnimation(.easeOut.speed(2)) {
                progressAlertManager.hide()
            } completion: {
                // TODO: Show an alert that the downloads may take some time to complete
            }
        } catch {
            debugPrint(error.localizedDescription)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    func redownloadIllustrations() {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let illustrations = try modelContext.fetch(FetchDescriptor<Illustration>())
            progressAlertManager.prepare("More.Files.RedownloadIllustrations.Redownloading",
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
                DispatchQueue.main.async {
                    progressAlertManager.incrementProgress()
                }
            }
            UIApplication.shared.isIdleTimerDisabled = false
            withAnimation(.easeOut.speed(2)) {
                progressAlertManager.hide()
            } completion: {
                // TODO: Show an alert that the downloads may take some time to complete
            }
        } catch {
            debugPrint(error.localizedDescription)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
