//
//  PicMateApp.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import CloudKitSyncMonitor
import SwiftUI
import SwiftData

@main
struct IllustMateApp: App {

    @StateObject var tabManager = TabManager()
    @StateObject var navigationManager = NavigationManager()
    @State var concurrency = ConcurrencyManager()
    @ObservedObject var syncMonitor = SyncMonitor.shared

    @AppStorage(wrappedValue: false, "DebugShowCloudStatusEverywhere") var showCloudStatusEverywhere: Bool

    var body: some Scene {
        WindowGroup {
            Group {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    MainTabView()
                } else {
                    MainSplitView()
                }
            }
            .overlay {
                if showCloudStatusEverywhere {
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if syncMonitor.syncStateSummary.isBroken {
                                HStack(alignment: .center, spacing: 2.0) {
                                    Text(syncMonitor.lastError?.localizedDescription ?? "")
                                    Image(systemName: "xmark.icloud.fill")
                                }
                            } else if syncMonitor.syncStateSummary.inProgress {
                                Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                            } else {
                                switch syncMonitor.syncStateSummary {
                                case .notStarted, .succeeded:
                                    Image(systemName: "checkmark.icloud.fill")
                                case .noNetwork:
                                    Image(systemName: "bolt.horizontal.icloud.fill")
                                default:
                                    HStack(alignment: .center, spacing: 2.0) {
                                        Text(syncMonitor.lastError?.localizedDescription ?? "")
                                        Image(systemName: "exclamationmark.icloud.fill")
                                    }
                                }
                            }
                        }
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                        Color.clear
                    }
                }
            }
            .environmentObject(tabManager)
            .environmentObject(navigationManager)
            .environment(concurrency)
            .task {
                createIfNotExists(illustrationsFolder)
                createIfNotExists(thumbnailsFolder)
                createIfNotExists(importsFolder)
                createIfNotExists(orphansFolder)
            }
        }
        .modelContainer(sharedModelContainer)
#if targetEnvironment(macCatalyst)
        .defaultSize(CGSize(width: 600.0, height: 500.0))
#endif
    }

    func createIfNotExists(_ url: URL?) {
        if let url, !directoryExistsAtPath(url) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }
    }

    func directoryExistsAtPath(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = true
        let exists = FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
