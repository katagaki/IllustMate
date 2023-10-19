//
//  MoreDataManagementView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import CloudKitSyncMonitor
import Komponents
import SwiftData
import SwiftUI

struct MoreDataManagementView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(ProgressAlertManager.self) var progressAlertManager
    @Environment(ConcurrencyManager.self) var concurrency
    @ObservedObject var syncMonitor = SyncMonitor.shared

    @Query var illustrations: [Illustration]
    @Query var albums: [Album]
    @Query var thumbnails: [Thumbnail]

    @AppStorage(wrappedValue: false, "DebugThumbnailTools") var showAdvancedThumbnailOptions: Bool

    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 16.0) {
                    Group {
                        if syncMonitor.syncStateSummary.isBroken {
                            Image(systemName: "xmark.icloud.fill")
                                .resizable()
                                .foregroundStyle(.red)
                        } else if syncMonitor.syncStateSummary.inProgress {
                            Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                                .resizable()
                                .foregroundStyle(.primary)
                        } else {
                            switch syncMonitor.syncStateSummary {
                            case .notStarted, .succeeded:
                                Image(systemName: "checkmark.icloud.fill")
                                    .resizable()
                                    .foregroundStyle(.green)
                            case .noNetwork:
                                Image(systemName: "bolt.horizontal.icloud.fill")
                                    .resizable()
                                    .foregroundStyle(.orange)
                            default:
                                Image(systemName: "exclamationmark.icloud.fill")
                                    .resizable()
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .symbolRenderingMode(.multicolor)
                    .scaledToFit()
                    .frame(width: 64.0, height: 64.0)
                    Group {
                        if syncMonitor.syncStateSummary.isBroken {
                            Text("More.Sync.State.Error")
                        } else if syncMonitor.syncStateSummary.inProgress {
                            Text("More.Sync.State.InProgress")
                        } else {
                            switch syncMonitor.syncStateSummary {
                            case .notStarted, .succeeded:
                                Text("More.Sync.State.Synced")
                            case .noNetwork:
                                Text("More.Sync.State.NoNetwork")
                            default:
                                Text("More.Sync.State.NotSyncing")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
            } header: {
                ListSectionHeader(text: "More.Sync")
                    .font(.body)
            } footer: {
                if isCloudSyncEnabled {
                    Text("More.Sync.Description")
                        .font(.body)
                }
            }
            Section {
                NavigationLink(value: ViewPath.moreDataAlbums(albums: albums)) {
                    HStack(alignment: .center, spacing: 8.0) {
                        Text("Shared.Albums")
                        Spacer(minLength: 0)
                        Text("\(albums.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink(value: ViewPath.moreDataIllustrations(illustrations: illustrations)) {
                    HStack(alignment: .center, spacing: 8.0) {
                        Text("Shared.Illustrations")
                        Spacer(minLength: 0)
                        Text("\(illustrations.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(alignment: .center, spacing: 8.0) {
                    Text("Shared.Thumbnails")
                    Spacer(minLength: 0)
                    Text("\(thumbnails.count)")
                        .foregroundStyle(.secondary)
                }
            }
            if showAdvancedThumbnailOptions {
                Section {
                    Button("More.DataManagement.RebuildThumbnails") {
                        rebuildThumbnails()
                    }
                    Button("More.DataManagement.RebuildThumbnails.MissingOnly") {
                        rebuildMissingThumbnails()
                    }
                    Button("More.DataManagement.UnorphanThumbnails", role: .destructive) {
                        removeOrphanedThumbnails()
                    }
                }
            }
        }
        .navigationTitle("ViewTitle.DataManagement")
        .navigationBarTitleDisplayMode(.inline)
    }

    func rebuildThumbnails() {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let illustrations = try modelContext.fetch(FetchDescriptor<Illustration>())
            progressAlertManager.prepare("More.DataManagement.RebuildThumbnails.Rebuilding",
                                         total: illustrations.count)
            progressAlertManager.show {
                try? modelContext.delete(model: Thumbnail.self, includeSubclasses: true)
                modelContext.autosaveEnabled = false
                illustrations.forEach { illustration in
                    autoreleasepool {
                        concurrency.queue.addOperation {
                            illustration.generateThumbnail()
                            progressAlertManager.incrementProgress()
                        }
                    }
                }
                concurrency.queue.addBarrierBlock {
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

    func rebuildMissingThumbnails() {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let illustrations = try modelContext.fetch(FetchDescriptor<Illustration>(
                predicate: #Predicate { $0.cachedThumbnail == nil }
            ))
            progressAlertManager.prepare("More.DataManagement.RebuildThumbnails.Rebuilding",
                                         total: illustrations.count)
            progressAlertManager.show {
                modelContext.autosaveEnabled = false
                illustrations.forEach { illustration in
                    autoreleasepool {
                        concurrency.queue.addOperation {
                            illustration.generateThumbnail()
                            progressAlertManager.incrementProgress()
                        }
                    }
                }
                concurrency.queue.addBarrierBlock {
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

    func removeOrphanedThumbnails() {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let thumbnails = try modelContext.fetch(FetchDescriptor<Thumbnail>(
                predicate: #Predicate { $0.illustration == nil }
            ))
            progressAlertManager.prepare("More.DataManagement.UnorphanThumbnails.Unorphaning",
                                         total: thumbnails.count)
            progressAlertManager.show {
                thumbnails.forEach { thumbnail in
                    modelContext.delete(thumbnail)
                    progressAlertManager.incrementProgress()
                }
                try? modelContext.save()
                modelContext.autosaveEnabled = true
                UIApplication.shared.isIdleTimerDisabled = false
                withAnimation(.easeOut.speed(2)) {
                    progressAlertManager.hide()
                }
            }
        } catch {
            debugPrint(error.localizedDescription)
            modelContext.autosaveEnabled = true
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
