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

    @State var isConfirmingRebuildThumbnails: Bool = false
    @State var isRebuildingThumbnails: Bool = false
    @State var rebuildProgress: Int = 0
    @State var rebuildTotal: Int = 0
    @State var isConfirmingFreeUpSpace: Bool = false
    @State var isFreeingUpSpace: Bool = false
    @State var isConfirmingClearCache: Bool = false

    var body: some View {
        List {
            Section {
                Button(String(localized: "Troubleshooting.RebuildThumbnails", table: "More")) {
                    isConfirmingRebuildThumbnails = true
                }
                Button(String(localized: "Troubleshooting.FreeUpSpace", table: "More")) {
                    isConfirmingFreeUpSpace = true
                }
                Button(String(localized: "Troubleshooting.ClearCache", table: "More")) {
                    isConfirmingClearCache = true
                }
            } header: {
                Text("Troubleshooting.DataManagement", tableName: "More")
            } footer: {
                Text("Troubleshooting.DataManagement.Description", tableName: "More")
            }
        }
        .navigationTitle("ViewTitle.Troubleshooting")
        .navigationBarTitleDisplayMode(.inline)
        .alert(Text("Troubleshooting.RebuildThumbnails.Confirm.Title", tableName: "More"),
               isPresented: $isConfirmingRebuildThumbnails) {
            Button("Shared.Yes", role: .destructive) {
                Task { await rebuildThumbnails() }
            }
            Button("Shared.No", role: .cancel) { }
        } message: {
            Text("Troubleshooting.RebuildThumbnails.Confirm.Message", tableName: "More")
        }
        .alert(Text("Troubleshooting.FreeUpSpace.Confirm.Title", tableName: "More"),
               isPresented: $isConfirmingFreeUpSpace) {
            Button("Shared.Yes", role: .destructive) {
                Task { await freeUpSpace() }
            }
            Button("Shared.No", role: .cancel) { }
        } message: {
            Text("Troubleshooting.FreeUpSpace.Confirm.Message", tableName: "More")
        }
        .alert(Text("Troubleshooting.ClearCache.Confirm.Title", tableName: "More"),
               isPresented: $isConfirmingClearCache) {
            Button("Shared.Yes", role: .destructive) {
                Task {
                    await HashActor.shared.deleteAllHashes()
                    await PColorActor.shared.deleteAllColors()
                    await CoverCacheActor.shared.deleteAllCovers()
                }
            }
            Button("Shared.No", role: .cancel) { }
        } message: {
            Text("Troubleshooting.ClearCache.Confirm.Message", tableName: "More")
        }
        .sheet(isPresented: $isRebuildingThumbnails) {
            RebuildThumbnailsProgressView(
                currentCount: $rebuildProgress, totalCount: $rebuildTotal
            )
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
