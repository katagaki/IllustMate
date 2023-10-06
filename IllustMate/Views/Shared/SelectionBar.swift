//
//  SelectionBar.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct SelectionBar<Content: View>: View {

    @Binding var illustrations: [Illustration]
    @Binding var selectedIllustrations: [Illustration]
    @ViewBuilder var menuItems: Content

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            Text("Shared.Selected.\(selectedIllustrations.count)")
            Spacer()
            if selectedIllustrations.count > 0 {
                menuItems
            }
            Button {
                if illustrations.count == selectedIllustrations.count {
                    selectedIllustrations.removeAll()
                } else {
                    selectedIllustrations.removeAll()
                    selectedIllustrations.append(contentsOf: illustrations)
                }
            } label: {
                if illustrations.count == selectedIllustrations.count {
                    Label("Shared.DeselectAll", systemImage: "rectangle.stack")
                } else {
                    Label("Shared.SelectAll", systemImage: "checkmark.rectangle.stack")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 99))
        .shadow(color: .black.opacity(0.15), radius: 4.0, x: 0.0, y: 4.0)
        .padding([.leading, .trailing, .bottom])
        .transition(.move(edge: .bottom).animation(.snappy.speed(2)))
    }
}
