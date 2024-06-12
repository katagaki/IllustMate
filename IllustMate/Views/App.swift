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
    @State var viewer = ViewerManager()
    @State var progressAlertManager = ProgressAlertManager()
    @State var concurrency = ConcurrencyManager()
    @ObservedObject var syncMonitor = SyncMonitor.shared

    @AppStorage(wrappedValue: false, "DebugCloudEverywhere") var showCloudStatusEverywhere: Bool

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
                        VStack(alignment: .trailing, spacing: 2.0) {
                            HStack(alignment: .center, spacing: 2.0) {
                                Text(syncMonitor.syncStateSummary.description)
                                if syncMonitor.syncStateSummary.isBroken {
                                    Image(systemName: "xmark.icloud.fill")
                                } else if syncMonitor.syncStateSummary.inProgress {
                                    Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                                } else {
                                    switch syncMonitor.syncStateSummary {
                                    case .notStarted, .succeeded:
                                        Image(systemName: "checkmark.icloud.fill")
                                    case .noNetwork:
                                        Image(systemName: "bolt.horizontal.icloud.fill")
                                    default:
                                        Image(systemName: "exclamationmark.icloud.fill")
                                    }
                                }
                            }
                            .foregroundStyle(.secondary)
                            Text(syncMonitor.lastError?.localizedDescription ?? "")
                                .foregroundStyle(.red)
                        }
                        .font(.caption2)
                        .padding(4.0)
                        Color.clear
                    }
                }
            }
            .environmentObject(tabManager)
            .environmentObject(navigationManager)
            .environment(viewer)
            .environment(progressAlertManager)
            .environment(concurrency)
            .task {
                createIfNotExists(illustrationsFolder)
                createIfNotExists(orphansFolder)
            }
        }
        .modelContainer(sharedModelContainer)
#if targetEnvironment(macCatalyst)
        .defaultSize(CGSize(width: 880.0, height: 680.0))
#endif
    }
}
