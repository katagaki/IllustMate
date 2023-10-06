//
//  SelectionOverlay.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct SelectionOverlay: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle()
                .foregroundStyle(.black)
                .opacity(0.5)
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 24.0, height: 24.0)
                .foregroundStyle(.white)
                .padding(8.0)
        }
            .transition(.scale.animation(.snappy.speed(4)))
    }
}
