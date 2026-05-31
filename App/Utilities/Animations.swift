import SwiftUI

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
