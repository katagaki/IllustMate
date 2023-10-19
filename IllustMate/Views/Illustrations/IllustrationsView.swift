//
//  IllustrationsView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftData
import SwiftUI

struct IllustrationsView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    @Environment(ConcurrencyManager.self) var concurrency
    @EnvironmentObject var navigationManager: NavigationManager

    let actor = DataActor(modelContainer: sharedModelContainer)

    @Namespace var illustrationTransitionNamespace

    @State var illustrations: [Illustration] = []

    @State var viewerManager = ViewerManager()

    @AppStorage(wrappedValue: true, "DebugThreadSafety") var useThreadSafeLoading: Bool

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
                .navigationTitle("ViewTitle.Illustrations")
            }
        }
        .illustrationViewerOverlay(namespace: illustrationTransitionNamespace, manager: $viewerManager)
#if targetEnvironment(macCatalyst)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Shared.Refresh") {
                    refreshIllustrations()
                }
            }
        }
#else
        .refreshable {
            refreshIllustrations()
        }
#endif
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
        if useThreadSafeLoading {
            Task.detached(priority: .userInitiated) {
                do {
                    let illustrations = try await actor.illustrations()
                    await MainActor.run {
                        self.illustrations = illustrations
                    }
                } catch {
                    debugPrint(error.localizedDescription)
                }
            }
        } else {
            concurrency.queue.addOperation {
                doWithAnimation {
                    do {
                        var fetchDescriptor = FetchDescriptor<Illustration>(
                            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
                        fetchDescriptor.propertiesToFetch = [\.name, \.dateAdded]
                        fetchDescriptor.relationshipKeyPathsForPrefetching = [\.cachedThumbnail]
                        illustrations = try modelContext.fetch(fetchDescriptor)
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
            }
        }
    }
}
