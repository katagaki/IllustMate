//
//  Animations.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/19.
//

import SwiftUI

func doWithAnimationAsynchronously(task: @escaping () -> Void, completion: (() -> Void)? = nil) {
    Task {
        await doWithAnimation {
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
    @AppStorage(wrappedValue: true, "DebugAllAnimsOff") var disableAllAnimations: Bool
    @AppStorage(wrappedValue: false, "DebugSlowAnims") var slowDownAnimations: Bool

    if disableAllAnimations {
        task()
        if let completion {
            completion()
        }
    } else {
        if slowDownAnimations {
            withAnimation(.snappy.speed(0.2)) {
                task()
            } completion: {
                if let completion {
                    completion()
                }
            }
        } else {
            withAnimation(.snappy.speed(2)) {
                task()
            } completion: {
                if let completion {
                    completion()
                }
            }
        }
    }
}
