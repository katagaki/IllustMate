//
//  SelectionOverlay.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct SelectionOverlay: View {
    let isSelected: Bool

    init(_ isSelected: Bool) {
        self.isSelected = isSelected
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isSelected {
                Color.black.opacity(0.3)
                    .clipShape(.rect(cornerRadius: 4.0))
            }
            ZStack {
                if isSelected {
                    Circle()
                        .fill(.accent)
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
            .padding(6)
        }
    }
}
