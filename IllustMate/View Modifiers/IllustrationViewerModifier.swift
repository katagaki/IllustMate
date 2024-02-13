//
//  IllustrationViewerModifier.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/17.
//

import SwiftUI

struct IllustrationViewerModifier: ViewModifier {

    var namespace: Namespace.ID
    @Binding var viewerManager: ViewerManager

    @AppStorage(wrappedValue: false, "DebugButterItUp") var butterItUp: Bool

    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            if butterItUp {
                content
                    .overlay {
                        if let image = viewerManager.displayedImage,
                           let illustration = viewerManager.displayedIllustration {
                            IllustrationViewer(namespace: namespace,
                                               illustration: illustration, displayedImage: image) {
                                viewerManager.removeDisplay()
                            }
                            .id(viewerManager.displayedIllustrationID)
                        }
                    }
            } else {
                content
                    .fullScreenCover(item: $viewerManager.displayedIllustration) { illustration in
                        if let image = viewerManager.displayedImage {
                            IllustrationViewer(namespace: namespace,
                                               illustration: illustration, displayedImage: image) {
                                viewerManager.removeDisplay()
                            }
                            .presentationBackground(.clear)
                        }
                    }
            }
        } else {
            content
        }
    }
}

extension View {
    func illustrationViewerOverlay(namespace: Namespace.ID, manager: Binding<ViewerManager>) -> some View {
        modifier(IllustrationViewerModifier(namespace: namespace, viewerManager: manager))
    }
}
