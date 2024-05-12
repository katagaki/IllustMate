//
//  ToggledTransitionModifier.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/20.
//

import SwiftUI

struct ToggledTransitionModifier: ViewModifier {

    var transition: AnyTransition

    func body(content: Content) -> some View {
        content
            .transition(transition)
    }
}

extension View {
    func toggledTransition(_ transition: AnyTransition) -> some View {
        modifier(ToggledTransitionModifier(transition: transition))
    }
}
