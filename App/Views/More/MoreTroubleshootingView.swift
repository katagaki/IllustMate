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

    @State var isDeleteConfirming: Bool = false
    @State var isRebuildingThumbnails: Bool = false
    @State var rebuildProgress: Int = 0
    @State var rebuildTotal: Int = 0
    @State var isFreeingUpSpace: Bool = false

    var body: some View {
        List {
            Section {
                Button(String(localized: "More.Troubleshooting.RebuildThumbnails", table: "More")) {
                    Task { await rebuildThumbnails() }
                }
                Button(String(localized: "More.Troubleshooting.FreeUpSpace", table: "More")) {
                    Task { await freeUpSpace() }
                }
                Button(String(localized: "More.Troubleshooting.ClearHashCache", table: "More")) {
                    Task { await HashActor.shared.deleteAllHashes() }
                }
                Button(String(localized: "More.Troubleshooting.ClearColorCache", table: "More")) {
                    Task { await PColorActor.shared.deleteAllColors() }
                }
            } header: {
                Text("More.Troubleshooting.DataManagement", tableName: "More")
            } footer: {
                Text("More.Troubleshooting.DataManagement.Description", tableName: "More")
            }
            Section {
                Button(String(localized: "More.Troubleshooting.DeleteAll", table: "More"), role: .destructive) {
                    isDeleteConfirming = true
                }
            }
        }
        .alert("Alert.DeleteAll.Title", isPresented: $isDeleteConfirming) {
            Button("Shared.Yes", role: .destructive) {
                Task {
                    await DataActor.shared.deleteAll()
                    navigation.signalDataDeleted()
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
        .sheet(isPresented: $isRebuildingThumbnails) {
            StatusView(type: .inProgress, title: .troubleshootingRebuildingThumbnails,
                       currentCount: rebuildProgress, totalCount: rebuildTotal)
            .phonePresentationDetents([.medium])
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isFreeingUpSpace) {
            StatusView(type: .inProgress, title: .troubleshootingFreeingUpSpace)
            .phonePresentationDetents([.medium])
            .interactiveDismissDisabled()
        }
    }

    func rebuildThumbnails() async {
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
            isRebuildingThumbnails = true
            rebuildProgress = 0
            rebuildTotal = 0
        }
        do {
            let pics = try await DataActor.shared.pics()
            await MainActor.run {
                rebuildTotal = pics.count
            }
            await DataActor.shared.deleteAllThumbnails()
            for pic in pics {
                if let data = await DataActor.shared.imageData(forPicWithID: pic.id) {
                    let thumbnailData = Pic.makeThumbnail(data)
                    await DataActor.shared.updateThumbnail(forPicWithID: pic.id,
                                                thumbnailData: thumbnailData)
                }
                await MainActor.run {
                    rebuildProgress += 1
                }
            }
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
                isRebuildingThumbnails = false
            }
        } catch {
            debugPrint(error.localizedDescription)
            await MainActor.run {
                UIApplication.shared.isIdleTimerDisabled = false
                isRebuildingThumbnails = false
            }
        }
    }

    func freeUpSpace() async {
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
            isFreeingUpSpace = true
        }
        await DataActor.shared.vacuum()
        await MainActor.run {
            isFreeingUpSpace = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
