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
    @EnvironmentObject var navigationManager: NavigationManager

    @Namespace var illustrationTransitionNamespace

    @Query(sort: [SortDescriptor<Illustration>(\.dateAdded, order: .reverse)],
           animation: .snappy.speed(2)) var illustrations: [Illustration]

    @State var viewerManager = ViewerManager()

    var body: some View {
        NavigationStack(path: $navigationManager.illustrationsTabPath) {
            ScrollView(.vertical) {
                IllustrationsGrid(namespace: illustrationTransitionNamespace,
                                  illustrations: .constant(illustrations),
                                  isSelecting: .constant(false),
                                  enableSelection: false) { illustration in
                    illustration.id == viewerManager.displayedIllustration?.id
                } isSelected: { _ in
                    return false
                } onSelect: { illustration in
                    withAnimation(.snappy.speed(2)) {
                        viewerManager.setDisplay(illustration)
                    }
                } selectedCount: {
                    return 0
                } onDelete: { illustration in
                    illustration.prepareForDeletion()
                    withAnimation(.snappy.speed(2)) {
                        modelContext.delete(illustration)
                    }
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
    }
}
