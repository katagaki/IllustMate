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
                VStack(alignment: .center, spacing: 16.0) {
                    Text(manager.title)
                        .multilineTextAlignment(.center)
                        .bold()
                    ProgressView(value: min(Float(manager.percentage), 100.0),
                                 total: 100.0)
                        .progressViewStyle(.linear)
                }
                .padding()
            }
            .background(.thickMaterial)
            .clipShape(.rect(cornerRadius: 16.0))
            .frame(maxWidth: 270.0)
            .padding(.all, 32.0)
        }
        .transition(.opacity)
    }
}
