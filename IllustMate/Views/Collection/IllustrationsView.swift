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
    @Environment(ConcurrencyManager.self) var concurrency
    @EnvironmentObject var navigationManager: NavigationManager

    @Namespace var illustrationTransitionNamespace

    @State var illustrations: [Illustration] = []

    @State var viewerManager = ViewerManager()

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
        .overlay {
            if let illustration = viewerManager.displayedIllustration,
               let image = viewerManager.displayedImage {
                IllustrationViewer(namespace: illustrationTransitionNamespace,
                                   illustration: illustration,
                                   displayedImage: image) {
                    withAnimation(.snappy.speed(2)) {
                        viewerManager.removeDisplay()
                    }
                }
            }
        }
        .onAppear {
            concurrency.queue.addOperation {
                withAnimation(.snappy.speed(2)) {
                    refreshIllustrations()
                }
            }
        }
    }

    func refreshIllustrations() {
        modelContext.autosaveEnabled = false
        do {
            var fetchDescriptor = FetchDescriptor<Illustration>(
                sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
            fetchDescriptor.propertiesToFetch = [\.name, \.dateAdded]
            fetchDescriptor.relationshipKeyPathsForPrefetching = [\.cachedThumbnail]
            illustrations = try modelContext.fetch(fetchDescriptor)
        } catch {
            debugPrint(error.localizedDescription)
        }
        modelContext.autosaveEnabled = true
    }
}
