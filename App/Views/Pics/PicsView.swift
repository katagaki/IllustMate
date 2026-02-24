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
    @AppStorage(wrappedValue: 4, "PicColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var columnCount: Int

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
#if targetEnvironment(macCatalyst)
                            Button("Shared.Refresh") {
                                refreshPics()
                            }
#endif
                            Menu {
                                Picker("Shared.GridSize",
                                       selection: $columnCount.animation(.smooth.speed(2.0))) {
                                    Text("Shared.GridSize.3")
                                        .tag(3)
                                    Text("Shared.GridSize.4")
                                        .tag(4)
                                    Text("Shared.GridSize.5")
                                        .tag(5)
                                    Text("Shared.GridSize.8")
                                        .tag(8)
                                }
                            } label: {
                                Image(systemName: "square.grid.2x2")
                            }
                        }
                    }
                }
#if !targetEnvironment(macCatalyst)
                .refreshable {
                    refreshPics()
                }
#endif
                .navigationTitle("ViewTitle.Pictures")
            }
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
