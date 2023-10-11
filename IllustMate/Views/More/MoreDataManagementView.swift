//
//  MoreDataManagementView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import SwiftData
import SwiftUI

struct MoreDataManagementView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @Query var illustrations: [Illustration]
    @Query var albums: [Album]
    @Query var thumbnails: [Thumbnail]

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
                Button("More.DataManagement.RebuildThumbnails") {
                    rebuildThumbnails()
                }
                Button("More.DataManagement.RebuildThumbnails.MissingOnly") {
                    rebuildMissingThumbnails()
                }
            }
        }
        .navigationTitle("ViewTitle.DataManagement")
        .navigationBarTitleDisplayMode(.inline)
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
}
