//
//  ProgressAlert.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import SwiftUI

struct ProgressAlert: View {

    @Environment(\.colorScheme) var colorScheme
    @Binding var manager: ProgressAlertManager

    var body: some View {
        ZStack(alignment: .center) {
            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .center, spacing: 0.0) {
                VStack(alignment: .center, spacing: 10.0) {
                    Text(manager.title)
                        .bold()
                    ProgressView(value: min(Float(manager.percentage), 100.0),
                                 total: 100.0)
                        .progressViewStyle(.linear)
                }
                .padding()
            }
            .background(.thickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16.0))
            .padding(.all, 32.0)
        }
        .transition(.opacity)
    }
}
