//
//  TransitionModifier.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/20.
//

import SwiftUI

struct TransitionModifier: ViewModifier {

    @AppStorage(wrappedValue: true, "DebugAllAnimsOff") var disableAllAnimations: Bool
    var transition: AnyTransition

    func body(content: Content) -> some View {
        if disableAllAnimations {
            content
        } else {
            content
                .transition(transition)
        }
    }
}

extension View {
    func transitionRespectingAnimationSetting(_ transition: AnyTransition) -> some View {
        modifier(TransitionModifier(transition: transition))
    }
}
