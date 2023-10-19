//
//  SelectionBar.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import Komponents
import SwiftUI

struct SelectionBar<Content: View>: View {

    var illustrations: [Illustration]
    @Binding var selectedIllustrations: [Illustration]
    var onStopSelecting: () -> Void
    @ViewBuilder var menuItems: Content

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            CloseButton {
                onStopSelecting()
            }
            Text("Shared.Selected.\(selectedIllustrations.count)")
            Spacer()
#if targetEnvironment(macCatalyst)
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
            Divider()
            menuItems
                .disabled(selectedIllustrations.count == 0)
#else
            Menu {
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
                Divider()
                menuItems
                    .disabled(selectedIllustrations.count == 0)
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title2)
            }
#endif
        }
        .padding(16.0)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 16.0))
        .shadow(color: .black.opacity(0.15), radius: 4.0, x: 0.0, y: 4.0)
        .padding([.leading, .trailing, .bottom], 8.0)
        .transition(.move(edge: .bottom).combined(with: .opacity).animation(.snappy.speed(2)))
    }
}
