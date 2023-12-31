//
//  SectionHeader.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import Komponents
import SwiftUI

struct SectionHeader<Content: View>: View {

    var title: LocalizedStringKey
    var count: Int
    @ViewBuilder var trailingViews: Content

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
#if targetEnvironment(macCatalyst)
            Menu("Shared.More") {
                trailingViews
            }
#else
            Menu {
                trailingViews
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
            }
#endif
        }
    }
}
