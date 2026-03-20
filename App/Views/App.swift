//
//  PicMateApp.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import BackgroundTasks
import StoreKit
import SwiftUI
import TipKit
import WidgetKit

@main
struct IllustMateApp: App {

    @Environment(\.scenePhase) var scenePhase
    @Environment(\.requestReview) var requestReview

    @StateObject var navigation = NavigationManager()
    @StateObject var libraryManager = LibraryManager()
    @State var viewer = ViewerManager()
    @State var concurrency = ConcurrencyManager()
    @State var photosManager = PhotosManager()
    @State var photosViewer = PhotosViewerManager()
    @State var auth = AuthenticationManager()
    @State var pipManager = PictureInPictureManager()
    @State var webServer = WebServerManager()
    @State var isImportingBackup: Bool = false
    @State var importedURL: URL?
    @State var showLockCover: Bool = false

    @AppStorage("AppLockEnabled",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var isAppLockEnabled: Bool = false
    @AppStorage(
        "LastVersionPromptedForReview",
        store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")
    ) var lastVersionPromptedForReview: String = ""

    static let widgetRefreshTaskID = "com.tsubuzaki.IllustMate.widgetRefresh"

    private var mainContent: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .phone {
                CollectionView()
            } else {
                MainSplitView()
            }
        }
        .environmentObject(navigation)
        .environmentObject(libraryManager)
        .environment(viewer)
        .environment(concurrency)
        .environment(photosManager)
        .environment(photosViewer)
        .environment(auth)
        .environment(pipManager)
        .environment(webServer)
        .overlay(alignment: .bottomLeading) {
            PictureInPictureLayerView(pipManager: pipManager)
                .frame(width: 1, height: 1)
                .opacity(0.001)
        }
        .onAppear {
            pipManager.setup()
        }
        .task {
            do {
                // TODO: Tips are broken in iOS 26 thanks to SwiftUI bug
                //       Will include everything for now until Apple fixes it
                try Tips.configure([
                    .displayFrequency(.immediate),
                    .datastoreLocation(.applicationDefault)
                ])
            } catch {
                debugPrint(error.localizedDescription)
            }
            await libraryManager.loadLibraries()
        }
        .onOpenURL { url in
            if url.pathExtension == "pics" {
                importedURL = url
            } else if url.scheme == "picmate", url.host == "album",
                      let albumID = url.pathComponents.dropFirst().first {
                Task {
                    if let album = await DataActor.shared.album(for: albumID) {
                        navigation.popAll()
                        try? await Task.sleep(for: .milliseconds(250))
                        navigation.push(.album(album: album), for: .collection)
                    }
                }
            }
        }
        .onChange(of: importedURL) { _, newValue in
            if newValue != nil {
                isImportingBackup = true
            }
        }
        .sheet(isPresented: $isImportingBackup) {
            importedURL = nil
        } content: {
            if let importedURL {
                RestoreBackupView(backupURL: importedURL)
                    .environmentObject(navigation)
            } else {
                ProgressView()
            }
        }
    }

    nonisolated func scheduleWidgetRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: IllustMateApp.widgetRefreshTaskID)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 24, to: .now)
        try? BGTaskScheduler.shared.submit(request)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                mainContent
                if showLockCover {
                    LockScreenView()
                        .environment(auth)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showLockCover)
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .background {
                    WidgetCenter.shared.reloadTimelines(ofKind: "Photostand")
                    WidgetCenter.shared.reloadTimelines(ofKind: "PhotoGrid")
                    scheduleWidgetRefresh()
                    webServer.stop()
                }
                if newValue == .active {
                    let currentVersion = Bundle.main.object(
                        forInfoDictionaryKey: "CFBundleShortVersionString"
                    ) as? String ?? ""
                    if ViewerManager.picOpenCount >= 6,
                       currentVersion != lastVersionPromptedForReview {
                        lastVersionPromptedForReview = currentVersion
                        requestReview()
                    }
                }
                if isAppLockEnabled {
                    switch newValue {
                    case .inactive:
                        showLockCover = true
                    case .background:
                        auth.lock()
                        showLockCover = true
                    case .active:
                        if auth.isUnlocked {
                            showLockCover = false
                        } else {
                            auth.authenticate()
                        }
                    @unknown default:
                        break
                    }
                }
            }
            .onChange(of: auth.isUnlocked) { _, isUnlocked in
                if isUnlocked {
                    showLockCover = false
                }
            }
        }
        .backgroundTask(.appRefresh(IllustMateApp.widgetRefreshTaskID)) {
            WidgetCenter.shared.reloadTimelines(ofKind: "Photostand")
            WidgetCenter.shared.reloadTimelines(ofKind: "PhotoGrid")
            scheduleWidgetRefresh()
        }
#if targetEnvironment(macCatalyst)
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Command.PreviousPic") {
                    viewer.navigateToPrevious()
                    photosViewer.navigateToPrevious()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(!viewer.hasPrevious && !photosViewer.hasPrevious)

                Button("Command.NextPic") {
                    viewer.navigateToNext()
                    photosViewer.navigateToNext()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(!viewer.hasNext && !photosViewer.hasNext)
            }
        }
#endif
    }
}
