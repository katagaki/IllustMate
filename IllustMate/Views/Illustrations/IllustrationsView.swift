//
//  IllustrationsView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftData
import SwiftUI

struct IllustrationsView: View {

    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var navigationManager: NavigationManager

    @Namespace var illustrationTransitionNamespace

    @State var illustrations: [Illustration] = []
    @State var viewerManager = ViewerManager()

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationManager.illustrationsTabPath) {
                ScrollView(.vertical) {
                    IllustrationsGrid(namespace: illustrationTransitionNamespace,
                                      illustrations: illustrations,
                                      isSelecting: .constant(false),
                                      enableSelection: false) { illustration in
                        illustration.id == viewerManager.displayedIllustrationID
                    } onSelect: { illustration in
                        viewerManager.setDisplay(illustration)
                    } selectedCount: {
                        return 0
                    } moveMenu: { _ in }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(alignment: .center, spacing: 8.0) {
                            Text("\(illustrations.count)")
                                .foregroundStyle(.secondary)
#if targetEnvironment(macCatalyst)
                            Button("Shared.Refresh") {
                                refreshIllustrations()
                            }
#endif
                        }
                    }
                }
#if !targetEnvironment(macCatalyst)
                .refreshable {
                    refreshIllustrations()
                }
#endif
                .navigationTitle("ViewTitle.Illustrations")
            }
        }
        .illustrationViewerOverlay(namespace: illustrationTransitionNamespace, manager: $viewerManager)
        .onAppear {
            refreshIllustrations()
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                refreshIllustrations()
            }
        }
    }

    func refreshIllustrations() {
        Task {
            do {
                let illustrations = try await actor.illustrations()
                await MainActor.run {
                    if isFB13295421Fixed {
                        doWithAnimation {
                            self.illustrations = illustrations
                        }
                    } else {
                        self.illustrations = illustrations
                    }
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
}
