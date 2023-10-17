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

    @AppStorage(wrappedValue: false, "DebugThreadSafety") var useThreadSafeLoading: Bool

    var body: some View {
        NavigationStack(path: $navigationManager.illustrationsTabPath) {
            ScrollView(.vertical) {
                IllustrationsGrid(namespace: illustrationTransitionNamespace,
                                  illustrations: .constant(illustrations),
                                  isSelecting: .constant(false),
                                  enableSelection: false) { illustration in
                    illustration.id == viewerManager.displayedIllustration?.id
                } onSelect: { illustration in
                    withAnimation(.snappy.speed(2)) {
                        viewerManager.setDisplay(illustration)
                    }
                } selectedCount: {
                    return 0
                } moveMenu: { _ in }
            }
            .navigationTitle("ViewTitle.Illustrations")
        }
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
        .illustrationViewerOverlay(namespace: illustrationTransitionNamespace, manager: viewerManager)
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
                withAnimation(.snappy.speed(2)) {
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
