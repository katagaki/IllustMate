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
    @ObservedObject var syncMonitor = SyncMonitor.shared

    @AppStorage(wrappedValue: false, "DebugShowCloudStatusEverywhere") var showCloudStatusEverywhere: Bool

    var body: some Scene {
        WindowGroup {
            Group {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    MainTabView()
                } else {
                    MainSplitView()
#if targetEnvironment(macCatalyst)
                        .frame(minWidth: 600.0, minHeight: 500.0)
#endif
                }
            }
            .overlay {
                if showCloudStatusEverywhere {
                    ZStack(alignment: .bottomTrailing) {
                        Color.clear
                        Group {
                            if syncMonitor.syncStateSummary.isBroken {
                                HStack(alignment: .center, spacing: 2.0) {
                                    Text(syncMonitor.lastError?.localizedDescription ?? "")
                                    Image(systemName: "xmark.icloud.fill")
                                        .resizable()
                                }
                            } else if syncMonitor.syncStateSummary.inProgress {
                                Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                                    .resizable()
                            } else {
                                switch syncMonitor.syncStateSummary {
                                case .notStarted, .succeeded:
                                    Image(systemName: "checkmark.icloud.fill")
                                        .resizable()
                                case .noNetwork:
                                    Image(systemName: "bolt.horizontal.icloud.fill")
                                        .resizable()
                                default:
                                    Image(systemName: "exclamationmark.icloud.fill")
                                        .resizable()
                                }
                            }
                        }
                        .foregroundStyle(.secondary)
                        .scaledToFit()
                        .frame(width: 16.0, height: 16.0)
                    }
                    .padding()
                }
            }
            .environmentObject(tabManager)
            .environmentObject(navigationManager)
            .task {
                createIfNotExists(illustrationsFolder)
                createIfNotExists(thumbnailsFolder)
                createIfNotExists(importsFolder)
                createIfNotExists(orphansFolder)
            }
        }
        .modelContainer(sharedModelContainer)
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
