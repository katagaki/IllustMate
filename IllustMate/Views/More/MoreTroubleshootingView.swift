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

    @EnvironmentObject var navigation: NavigationManager
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
                Button("More.Troubleshooting.FreeUpSpace") {
                    Task {
                        await dataActor.vacuum()
                    }
                }
            } header: {
                Text("More.Troubleshooting.DataManagement")
            } footer: {
                Text("More.Troubleshooting.DataManagement.Description")
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
                    await dataActor.deleteAll()
                    navigation.popAll()
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
            let pics = try await dataActor.pics()
            await MainActor.run {
                progressAlertManager.prepare("More.Troubleshooting.RebuildThumbnails.Rebuilding",
                                             total: pics.count)
            }
            await dataActor.deleteAllThumbnails()
            await MainActor.run {
                progressAlertManager.show()
            }
            for pic in pics {
                if let data = await dataActor.imageData(forPicWithID: pic.id) {
                    let thumbnailData = Pic.makeThumbnail(data)
                    await dataActor.updateThumbnail(forPicWithID: pic.id,
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
}
