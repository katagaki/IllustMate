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
    @State var picToRename: Pic?
    @State var viewerManager = ViewerManager()

    var body: some View {
        ZStack {
            NavigationStack(path: $navigation.picsTabPath) {
                ScrollView(.vertical) {
                    PicsGrid(namespace: namespace,
                             pics: pics,
                             isSelecting: .constant(false),
                             enableSelection: false) { pic in
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            viewer.setDisplay(pic, in: pics) { [navigation] in
                                navigation.push(.picViewer(namespace: namespace), for: .pics)
                            }
                        } else {
                            viewer.setDisplay(pic, in: pics) { }
                        }
                    } selectedCount: {
                        return 0
                    } onRename: { pic in
                        picToRename = pic
                    } moveMenu: { _ in
                        // TODO: Move menu support in macOS Pics view
                    }
                }
                .toolbar {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        ToolbarItem(placement: .topBarTrailing) {
                            HStack(alignment: .center, spacing: 8.0) {
                                Text("\(pics.count)")
                                    .foregroundStyle(.secondary)
                            }
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
            .onChange(of: navigation.dataVersion) { _, _ in
                refreshPics()
            }
            .sheet(item: $picToRename) {
                refreshPics()
            } content: { pic in
                RenamePicView(pic: pic)
            }
        }
    }

    func refreshPics() {
        Task.detached(priority: .userInitiated) {
            do {
                let pics = try await DataActor.shared.pics()
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
