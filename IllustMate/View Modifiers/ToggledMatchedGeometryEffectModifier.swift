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

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(id: id, in: namespace)
    }
}

extension View {
    func toggledMatchedGeometryEffect(id: String, in namespace: Namespace.ID) -> some View {
        modifier(ToggledMatchedGeometryEffectModifier(id: id, namespace: namespace))
    }
}
