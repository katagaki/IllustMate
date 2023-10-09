//
//  MoreDebugView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftData
import SwiftUI

struct MoreDebugView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @State var orphans: [String] = []

    @AppStorage(wrappedValue: false, "DebugShowIllustrationIDs") var showIllustrationIDs: Bool

    @Binding var progressAlertManager: ProgressAlertManager

    var body: some View {
        List {
            Section {
                Toggle("More.Debug.ShowIllustrationIDs", isOn: $showIllustrationIDs)
            }
            Section {
                Button("More.Debug.ScanForOrphans") {
                    scanForOrphans()
                }
                Button("More.Debug.ViewOrphans") {
                    let orphanFiles = try? FileManager.default.contentsOfDirectory(
                        atPath: orphansFolder.path(percentEncoded: false))
                    if let orphanFiles {
                        var orphans: [String] = []
                        for orphanFile in orphanFiles {
                            let orphanFileName = URL(filePath: orphanFile).lastPathComponent
                            if orphanFileName != ".DS_Store" {
                                orphans.append(orphanFileName)
                            }
                        }
                        navigationManager.push(ViewPath.moreOrphans(orphans: orphans), for: .more)
                    }
                }
            }
            Section {
                Button("More.Debug.RebuildThumbnails") {
                    rebuildThumbnails()
                }
                Button("More.Debug.RedownloadThumbnails") {
                    redownloadThumbnails()
                }
            }
        }
        .navigationTitle("ViewTitle.Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

    func scanForOrphans() {
        UIApplication.shared.isIdleTimerDisabled = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var fetchDescriptor = FetchDescriptor<Illustration>()
                fetchDescriptor.propertiesToFetch = [\.id]
                let illustrations = try modelContext.fetch(fetchDescriptor)
                progressAlertManager.prepare("More.Debug.ScanForOrphans.Scanning")
                withAnimation(.easeOut.speed(2)) {
                    progressAlertManager.show()
                }
                let filesToCheck = try FileManager.default
                    .contentsOfDirectory(at: illustrationsFolder, includingPropertiesForKeys: nil)
                orphans.removeAll()
                progressAlertManager.prepare("More.Debug.ScanForOrphans.Scanning",
                                             total: filesToCheck.count)
                for file in filesToCheck {
                    if !illustrations.contains(where: { file.lastPathComponent.contains($0.id) }) {
                        orphans.append(file.lastPathComponent)
                    }
                    progressAlertManager.incrementProgress()
                }
                progressAlertManager.prepare("More.Debug.ScanForOrphans.Moving", total: orphans.count)
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
            progressAlertManager.prepare("More.Debug.RebuildThumbnails.Rebuilding",
                                         total: illustrations.count)
            withAnimation(.easeOut.speed(2)) {
                progressAlertManager.show()
            }
            try FileManager.default.removeItem(at: thumbnailsFolder)
            try FileManager.default.createDirectory(at: thumbnailsFolder,
                                                    withIntermediateDirectories: false)
            Task {
                await withDiscardingTaskGroup { group in
                    for illustration in illustrations {
                        group.addTask {
                            // Generate thumbnail
                            let illustrationImage = UIImage(contentsOfFile: illustration.illustrationPath())
                            if let illustrationImage, let thumbnailData = Illustration
                                .makeThumbnail(illustrationImage.jpegData(compressionQuality: 1.0)) {
                                FileManager.default.createFile(atPath: illustration.thumbnailPath(),
                                                               contents: thumbnailData)
                            }
                            await progressAlertManager.incrementProgress()
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
            progressAlertManager.prepare("More.Debug.RedownloadThumbnails.Redownloading",
                                         total: illustrations.count)
            withAnimation(.easeOut.speed(2)) {
                progressAlertManager.show()
            }
            Task {
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
}
