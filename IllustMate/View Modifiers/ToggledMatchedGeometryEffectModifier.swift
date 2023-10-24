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

    let isFB13295421Fixed: Bool = false

    func body(content: Content) -> some View {
        if isFB13295421Fixed {
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
