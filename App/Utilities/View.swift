import SwiftUI

extension View {
    @MainActor func render(scale displayScale: CGFloat = 1.0) -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = displayScale
        return renderer.uiImage
    }

    @ViewBuilder
    func `if`<Modified: View>(_ condition: Bool, modifier: (Self) -> Modified) -> some View {
        if condition {
            modifier(self)
        } else {
            self
        }
    }
}
