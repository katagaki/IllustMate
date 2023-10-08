//
//  IllustrationsView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftData
import SwiftUI

struct IllustrationsView: View {

    @Namespace var illustrationTransitionNamespace

    @Query(sort: [SortDescriptor<Illustration>(\.name, order: .reverse)],
           animation: .snappy.speed(2)) var illustrations: [Illustration]

    @State var displayedIllustration: Illustration?

    var body: some View {
        // TODO: Improve performance
        // This view has HORRIBLE performance! It needs to be improved.
        ScrollView(.vertical) {
            IllustrationsGrid(namespace: illustrationTransitionNamespace,
                              illustrations: .constant(illustrations), isSelecting: .constant(false)) { illustration in
                illustration.id == displayedIllustration?.id
            } isSelected: { illustration in
                return false
            } onSelect: { illustration in
                // TODO
            } selectedCount: {
                return 0
            } onDelete: { illustration in
                // TODO
            } moveMenu: { illustration in
                // TODO
            }
        }
        .navigationTitle("ViewTitle.Illustrations")
    }
}
