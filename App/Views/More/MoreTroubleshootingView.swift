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
                Button("More.Troubleshooting.RebuildThumbnails") {
                    Task { await rebuildThumbnails() }
                }
                Button("More.Troubleshooting.FreeUpSpace") {
                    Task { await freeUpSpace() }
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
        .sheet(isPresented: $isRebuildingThumbnails) {
            StatusView(type: .inProgress, title: "More.Troubleshooting.RebuildThumbnails.Rebuilding",
                       currentCount: rebuildProgress, totalCount: rebuildTotal)
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isFreeingUpSpace) {
            StatusView(type: .inProgress, title: "More.Troubleshooting.FreeUpSpace.Freeing")
            .presentationDetents([.medium])
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
            let pics = try await dataActor.pics()
            await MainActor.run {
                rebuildTotal = pics.count
            }
            await dataActor.deleteAllThumbnails()
            for pic in pics {
                if let data = await dataActor.imageData(forPicWithID: pic.id) {
                    let thumbnailData = Pic.makeThumbnail(data)
                    await dataActor.updateThumbnail(forPicWithID: pic.id,
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
        await dataActor.vacuum()
        await MainActor.run {
            isFreeingUpSpace = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
