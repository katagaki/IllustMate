import SwiftUI

@MainActor
enum CopiedToast {
    static func showCopied() {
        ToastManager.shared.show(ToastItem(
            message: String(localized: "Toast.Copied", table: "Photos"),
            systemImage: "doc.on.doc.fill"))
    }
}
