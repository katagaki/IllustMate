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

    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content
                .overlay {
                    if viewerManager.displayedIllustrationID != "" {
                        if let image = viewerManager.displayedImage,
                           let illustration = viewerManager.displayedIllustration {
                            IllustrationViewer(namespace: namespace,
                                               illustration: illustration, displayedImage: image) {
                                viewerManager.removeDisplay()
                            }
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
