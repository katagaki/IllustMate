//
//  View.swift
//  PicMate
//
//  Created on 2026/03/11.
//

import SwiftUI

extension View {
    /// Applies presentation detents only on iPhone. On iPad, sheets present at their natural size.
    @ViewBuilder
    func phonePresentationDetents(_ detents: Set<PresentationDetent>) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            self.presentationDetents(detents)
        } else {
            self
        }
    }
}
