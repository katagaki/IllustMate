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

    @State var showOrphanedFilesViewFlag: Bool = false

    var body: some View {
        List {
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
