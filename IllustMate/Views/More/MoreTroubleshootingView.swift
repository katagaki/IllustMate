//
//  MoreTroubleshootingView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import Komponents
import SwiftUI
import UIKit

struct MoreTroubleshootingView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(ConcurrencyManager.self) var concurrency
    @Environment(ProgressAlertManager.self) var progressAlertManager

    @State var isDeleteConfirming: Bool = false

    var body: some View {
        List {
            Section {
                Button("More.Troubleshooting.RebuildThumbnails") {
                    Task {
                        await rebuildThumbnails()
                    }
                }
            } header: {
                ListSectionHeader(text: "More.Troubleshooting.DataManagement")
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
                    navigationManager.popAll()
                }
            }
            Button("Shared.No", role: .cancel) {
                isDeleteConfirming = false
            }
        } message: {
            Text("Alert.DeleteAll.Text")
        }
        .navigationTitle("ViewTitle.Troubleshooting")
        .navigationBarTitleDisplayMode(.inline)
    }

    func rebuildThumbnails() async {
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        do {
            let illustrations = try await actor.illustrations()
            await MainActor.run {
                progressAlertManager.prepare("More.Troubleshooting.RebuildThumbnails.Rebuilding",
                                             total: illustrations.count)
            }
            await actor.deleteAllThumbnails()
            await MainActor.run {
                progressAlertManager.show()
            }
            for illustration in illustrations {
                if let data = await actor.imageData(forIllustrationWithID: illustration.id) {
                    let thumbnailData = Illustration.makeThumbnail(data)
                    await actor.updateThumbnail(forIllustrationWithID: illustration.id,
                                                thumbnailData: thumbnailData)
                }
                await MainActor.run {
                    progressAlertManager.incrementProgress()
                }
            }
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
                progressAlertManager.hide()
            }
        } catch {
            debugPrint(error.localizedDescription)
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    func deleteData() async {
        await actor.deleteAll()
    }
}
