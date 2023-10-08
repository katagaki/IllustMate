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

    @Namespace var illustrationTransitionNamespace

    @Query(sort: [SortDescriptor<Illustration>(\.name, order: .reverse)],
           animation: .snappy.speed(2)) var illustrations: [Illustration]

    @State var displayedIllustration: Illustration?
    @State var illustrationDisplayOffset: CGSize = .zero

    var body: some View {
        ScrollView(.vertical) {
            IllustrationsGrid(namespace: illustrationTransitionNamespace,
                              illustrations: .constant(illustrations),
                              isSelecting: .constant(false),
                              enableSelection: false) { illustration in
                illustration.id == displayedIllustration?.id
            } isSelected: { _ in
                return false
            } onSelect: { illustration in
                withAnimation(.snappy.speed(2)) {
                    displayedIllustration = illustration
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
        .overlay {
            if let displayedIllustration {
                IllustrationViewer(namespace: illustrationTransitionNamespace,
                                   displayedIllustration: displayedIllustration,
                                   illustrationDisplayOffset: $illustrationDisplayOffset) {
                    withAnimation(.snappy.speed(2)) {
                        self.displayedIllustration = nil
                    } completion: {
                        illustrationDisplayOffset = .zero
                    }
                }
            }
        }
        .navigationTitle("ViewTitle.Illustrations")
    }
}
