//
//  Animations.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/19.
//

import SwiftUI

@MainActor
func doWithAnimationAsynchronously(task: @escaping @Sendable () -> Void,
                                   completion: (@Sendable () -> Void)? = nil) {
    Task { @MainActor in
        doWithAnimation {
            task()
        } completion: {
            if let completion {
                completion()
            }
        }
    }
}

@MainActor
func doWithAnimation(task: @escaping () -> Void, completion: (() -> Void)? = nil) {
    withAnimation(.smooth.speed(2)) {
        task()
    } completion: {
        if let completion {
            completion()
        }
    }
}
