//
//  CollectionHeader.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import Komponents
import SwiftUI

struct CollectionHeader<Content: View>: View {

    @State var title: LocalizedStringKey
    @State var count: Int
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
            trailingViews
        }
    }
}
