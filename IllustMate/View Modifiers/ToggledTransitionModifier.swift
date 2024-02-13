//
//  ToggledTransitionModifier.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/20.
//

import SwiftUI

struct ToggledTransitionModifier: ViewModifier {

    var transition: AnyTransition

    @AppStorage(wrappedValue: false, "DebugButterItUp") var butterItUp: Bool

    func body(content: Content) -> some View {
        if butterItUp {
            content
                .transition(transition)
        } else {
            content
        }
    }
}

extension View {
    func toggledTransition(_ transition: AnyTransition) -> some View {
        modifier(ToggledTransitionModifier(transition: transition))
    }
}
