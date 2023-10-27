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
            if showAdvancedThumbnailOptions {
                Section {
                    Button("More.DataManagement.RebuildThumbnails") {
                        Task {
                            await rebuildThumbnails()
                        }
                    }
                    Button("More.DataManagement.UnorphanThumbnails", role: .destructive) {
                        Task {
                            await removeOrphanedThumbnails()
                        }
                    }
                }
            }
        }
        .navigationTitle("ViewTitle.DataManagement")
        .navigationBarTitleDisplayMode(.inline)
    }

    func rebuildThumbnails() async {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let illustrations = try await actor.illustrations()
            progressAlertManager.prepare("More.DataManagement.RebuildThumbnails.Rebuilding", total: illustrations.count)
            await actor.deleteAllThumbnails()
            progressAlertManager.show()
            let coordinator = NSFileCoordinator()
            for illustration in illustrations {
                let url = URL(filePath: illustration.illustrationPath())
                let intent = NSFileAccessIntent.readingIntent(with: url)
                coordinator.coordinate(with: [intent], queue: concurrency.queue) { error in
                    if let error {
                        debugPrint(error.localizedDescription)
                        Task {
                            await MainActor.run {
                                progressAlertManager.incrementProgress()
                            }
                        }
                    } else {
                        Task {
                            illustration.generateThumbnail()
                            await MainActor.run {
                                progressAlertManager.incrementProgress()
                                if progressAlertManager.percentage >= 100 {
                                    Task {
                                        await actor.save()
                                    }
                                    UIApplication.shared.isIdleTimerDisabled = false
                                    progressAlertManager.hide()
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            debugPrint(error.localizedDescription)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    func removeOrphanedThumbnails() async {
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let thumbnails = try await actor.thumbnails()
            progressAlertManager.prepare("More.DataManagement.UnorphanThumbnails.Unorphaning", total: thumbnails.count)
            progressAlertManager.show()
            for thumbnail in thumbnails {
                if thumbnail.illustration == nil {
                    await actor.deleteThumbnail(withIdentifier: thumbnail.persistentModelID)
                }
                await MainActor.run {
                    progressAlertManager.incrementProgress()
                }
            }
            UIApplication.shared.isIdleTimerDisabled = false
            progressAlertManager.hide()
        } catch {
            debugPrint(error.localizedDescription)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
