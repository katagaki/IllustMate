//
//  ToggledMatchedGeometryEffectModifier.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/25.
//

import SwiftUI

struct ToggledMatchedGeometryEffectModifier: ViewModifier {

    var id: String
    var namespace: Namespace.ID

    @AppStorage(wrappedValue: false, "DebugButterItUp") var butterItUp: Bool

    func body(content: Content) -> some View {
        if butterItUp {
            content
                .matchedGeometryEffect(id: id, in: namespace)
        } else {
            content
        }
    }
}

extension View {
    func toggledMatchedGeometryEffect(id: String, in namespace: Namespace.ID) -> some View {
        modifier(ToggledMatchedGeometryEffectModifier(id: id, namespace: namespace))
    }
}
