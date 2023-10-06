//
//  IllustrationLabel.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct IllustrationLabel: View {
    let url: URL
    @State var shouldDisplay: Bool = true

    init(_ url: URL) {
        self.url = url
    }

    var body: some View {
        ZStack {
            Group {
                if shouldDisplay {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                    } placeholder: {
                        Rectangle()
                            .foregroundStyle(.clear)
                    }
                } else {
                    Rectangle()
                        .foregroundStyle(.clear)
                }
            }
            .transition(.opacity.animation(.snappy.speed(2)))
        }
        .aspectRatio(1.0, contentMode: .fill)
        .onAppear {
            shouldDisplay = true
        }
        .onDisappear {
            shouldDisplay = false
        }
        .transition(.opacity.animation(.snappy.speed(2)))
    }
}
