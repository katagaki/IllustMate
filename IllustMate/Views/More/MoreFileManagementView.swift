//
//  MoreFileManagementView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/11.
//

import SwiftData
import SwiftUI

struct MoreFileManagementView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(ConcurrencyManager.self) var concurrency
    @EnvironmentObject var navigationManager: NavigationManager

    @Binding var progressAlertManager: ProgressAlertManager

    var body: some View {
        List {
            Section {
                Button("More.FileManagement.Orphans") {
                    scanForOrphans()
                }
                Button("More.FileManagement.Orphans.View") {
                    showOrphans()
                }
            }
            Section {
                Button("More.FileManagement.RedownloadIllustrations") {
                    redownloadIllustrations()
                }
            }
        }
        .navigationTitle("ViewTitle.FileManagement")
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
                progressAlertManager.prepare("More.FileManagement.Orphans.Scanning")
                withAnimation(.easeOut.speed(2)) {
                    progressAlertManager.show()
                }
                let filesToCheck = try FileManager.default
                    .contentsOfDirectory(at: illustrationsFolder, includingPropertiesForKeys: nil)
                progressAlertManager.prepare("More.FileManagement.Orphans.Scanning",
                                             total: filesToCheck.count)
                Task.detached(priority: .background) {
                    debugPrint("Checking \(filesToCheck.count) files")
                    let orphans: [String] = await withTaskGroup(of: String?.self, returning: [String].self) { group in
                        var orphans: [String] = []
                        for file in filesToCheck {
                            group.addTask {
                                if !illustrations.contains(where: { file.lastPathComponent.contains($0.id) }) {
                                    return file.lastPathComponent
                                }
                                return nil
                            }
                            await progressAlertManager.incrementProgress()
                        }
                        for await result in group {
                            if let result {
                                orphans.append(result)
                            }
                        }
                        return orphans
                    }
                    await progressAlertManager.prepare("More.FileManagement.Orphans.Moving", total: orphans.count)
                    await MainActor.run { [orphans] in
                        orphans.forEach { orphan in
                            try? FileManager.default.moveItem(
                                at: illustrationsFolder.appendingPathComponent(orphan),
                                to: orphansFolder.appendingPathComponent(orphan))
                            progressAlertManager.incrementProgress()
                        }
                    }
                    await MainActor.run {
                        debugPrint("Completing orphan scan")
                        UIApplication.shared.isIdleTimerDisabled = false
                        withAnimation(.easeOut.speed(2)) {
                            progressAlertManager.hide()
                        } completion: {
                            if !orphans.isEmpty {
                                navigationManager.push(ViewPath.moreOrphans(orphans: orphans), for: .more)
                            }
                        }
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
        concurrency.queue.addOperation {
            do {
                let illustrations = try modelContext.fetch(FetchDescriptor<Illustration>())
                progressAlertManager.prepare("More.FileManagement.RedownloadIllustrations.Redownloading",
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
