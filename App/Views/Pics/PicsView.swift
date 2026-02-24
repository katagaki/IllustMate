//
//  PicsView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftUI

struct PicsView: View {

    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var navigation: NavigationManager
    @Environment(ViewerManager.self) var viewer

    @Namespace var namespace

    @State var pics: [Pic] = []
    @State var viewerManager = ViewerManager()

    var body: some View {
        ZStack {
            NavigationStack(path: $navigation.picsTabPath) {
                ScrollView(.vertical) {
                    PicsGrid(namespace: namespace,
                             pics: pics,
                             isSelecting: .constant(false),
                             enableSelection: false) { pic in
                        viewer.setDisplay(pic) { [navigation] in
                            navigation.push(.picViewer(namespace: namespace), for: .pics)
                        }
                    } selectedCount: {
                        return 0
                    } moveMenu: { _ in
                        // TODO: Move menu support in macOS Pics view
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(alignment: .center, spacing: 8.0) {
                            Text("\(pics.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("ViewTitle.Pics")
            }
            .onAppear {
                refreshPics()
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    refreshPics()
                }
            }
        }
    }

    func refreshPics() {
        Task.detached(priority: .userInitiated) {
            do {
                let pics = try await dataActor.pics()
                await MainActor.run {
                    doWithAnimation {
                        self.pics = pics
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
}
