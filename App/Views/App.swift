//
//  PicMateApp.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI
import WidgetKit

@main
struct IllustMateApp: App {

    @Environment(\.scenePhase) var scenePhase

    @StateObject var navigation = NavigationManager()
    @State var viewer = ViewerManager()
    @State var concurrency = ConcurrencyManager()
    @State var photosManager = PhotosManager()
    @State var photosViewer = PhotosViewerManager()
    @State var auth = AuthenticationManager()
    @State var pipManager = PictureInPictureManager()
    @State var isImportingBackup: Bool = false
    @State var importedURL: URL?
    @State var showLockCover: Bool = false

    @AppStorage("AppLockEnabled",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var isAppLockEnabled: Bool = false

    private var mainContent: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .phone {
                CollectionView()
            } else {
                MainSplitView()
            }
        }
        .environmentObject(navigation)
        .environment(viewer)
        .environment(concurrency)
        .environment(photosManager)
        .environment(photosViewer)
        .environment(auth)
        .environment(pipManager)
        .background {
            PictureInPictureLayerView(pipManager: pipManager)
        }
        .onAppear {
            pipManager.setup()
        }
        .onOpenURL { url in
            if url.pathExtension == "pics" {
                importedURL = url
            } else if url.scheme == "picmate", url.host == "album",
                      let albumID = url.pathComponents.dropFirst().first {
                Task {
                    if let album = await DataActor.shared.album(for: albumID) {
                        navigation.popAll()
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
            } else {
                ProgressView()
            }
        }
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
#if targetEnvironment(macCatalyst)
        .defaultSize(CGSize(width: 880.0, height: 680.0))
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
