//
//  SectionHeader.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import Komponents
import SwiftUI

struct SectionHeader<Buttons: View, Content: View>: View {

    var title: LocalizedStringKey
    var count: Int
    @ViewBuilder var buttons: () -> Buttons
    @ViewBuilder var trailingViews: () -> Content

    init(title: LocalizedStringKey, count: Int, @ViewBuilder trailingViews: @escaping () -> Content) where Buttons == EmptyView {
        self.title = title
        self.count = count
        self.buttons = { EmptyView() }
        self.trailingViews = trailingViews
    }

    init(title: LocalizedStringKey, count: Int, @ViewBuilder buttons: @escaping () -> Buttons, @ViewBuilder trailingViews: @escaping () -> Content) {
        self.title = title
        self.count = count
        self.buttons = buttons
        self.trailingViews = trailingViews
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            HStack(alignment: .center, spacing: 8.0) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .textCase(nil)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .allowsTightening(true)
                if count != 0 {
                    Text("(\(count))")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            buttons()
#if targetEnvironment(macCatalyst)
            Menu("Shared.More") {
                trailingViews()
            }
#else
            Menu {
                trailingViews()
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 18.0, height: 18.0, alignment: .center)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
#endif
        }
    }
}
