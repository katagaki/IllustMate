//
//  IllustrationViewerModifier.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/17.
//

import SwiftUI

struct IllustrationViewerModifier: ViewModifier {

    var namespace: Namespace.ID
    var viewerManager: ViewerManager

    func body(content: Content) -> some View {
        content
            .overlay {
                if let illustration = viewerManager.displayedIllustration,
                   let image = viewerManager.displayedImage {
                    IllustrationViewer(namespace: namespace,
                                       illustration: illustration,
                                       displayedImage: image) {
                        withAnimation(.snappy.speed(2)) {
                            viewerManager.removeDisplay()
                        }
                    }
                }
            }
    }
}

extension View {
    func illustrationViewerOverlay(namespace: Namespace.ID, manager: ViewerManager) -> some View {
        modifier(IllustrationViewerModifier(namespace: namespace, viewerManager: manager))
    }
}
