import SwiftUI

let viewerFitToScreenKey = "ViewerFitToScreen"
let viewerBackgroundTypeKey = "ViewerBackgroundType"
let viewerShowResolutionKey = "ViewerShowResolutionByDefault"

enum ViewerBackgroundType: String, CaseIterable, Identifiable {
    case immersive
    case followSystem
    case dark

    var id: String { rawValue }
}
