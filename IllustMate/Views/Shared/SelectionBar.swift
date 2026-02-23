//
//  SelectionBar.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import Komponents
import SwiftUI

struct SelectionBar<Content: View>: View {

    var pics: [Pic]
    @Binding var selectedPics: [Pic]
    var onStopSelecting: () -> Void
    @ViewBuilder var menuItems: Content

    var body: some View {
        Group {
#if targetEnvironment(macCatalyst)
            VStack(alignment: .leading, spacing: 8.0) {
                HStack(alignment: .center, spacing: 8.0) {
                    CloseButton {
                        onStopSelecting()
                    }
                    Text("Shared.Selected.\(selectedPics.count)")
                }
                Divider()
                HStack(alignment: .center, spacing: 8.0) {
                    Spacer()
                    Button {
                        if pics.count == selectedPics.count {
                            selectedPics.removeAll()
                        } else {
                            selectedPics.removeAll()
                            selectedPics.append(contentsOf: pics)
                        }
                    } label: {
                        if pics.count == selectedPics.count {
                            Label("Shared.DeselectAll", systemImage: "rectangle.stack")
                        } else {
                            Label("Shared.SelectAll", systemImage: "checkmark.rectangle.stack")
                        }
                    }
                    menuItems
                        .disabled(selectedPics.count == 0)
                    Spacer()
                }
            }
            .padding(8.0)
#else
            HStack(alignment: .center, spacing: 16.0) {
                Button {
                    onStopSelecting()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 24.0, height: 24.0, alignment: .center)
                }
                .frame(width: 24.0, height: 24.0, alignment: .center)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                Text("Shared.Selected.\(selectedPics.count)")
                Spacer()
                Menu {
                    Button {
                        if pics.count == selectedPics.count {
                            selectedPics.removeAll()
                        } else {
                            selectedPics.removeAll()
                            selectedPics.append(contentsOf: pics)
                        }
                    } label: {
                        if pics.count == selectedPics.count {
                            Label("Shared.DeselectAll", systemImage: "rectangle.stack")
                        } else {
                            Label("Shared.SelectAll", systemImage: "checkmark.rectangle.stack")
                        }
                    }
                    Divider()
                    menuItems
                        .disabled(selectedPics.count == 0)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 24.0, height: 24.0, alignment: .center)
                }
                .frame(width: 24.0, height: 24.0, alignment: .center)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
            .padding(20.0)
#endif
        }
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .capsule)
        .tint(.primary)
        .padding([.horizontal, .bottom])
        .transition(.move(edge: .bottom).combined(with: .opacity).animation(.smooth.speed(2)))
    }
}
