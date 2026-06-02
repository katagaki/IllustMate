import SwiftUI

struct PicExportDraggableModifier: ViewModifier {

    let pic: Pic

    @ViewBuilder
    func body(content: Content) -> some View {
        if pic.isVideo {
            content.draggable(PicVideoExportable(id: pic.id, name: pic.name))
        } else {
            content.draggable(PicImageExportable(id: pic.id, name: pic.name))
        }
    }
}
