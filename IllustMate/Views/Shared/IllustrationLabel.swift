//
//  IllustrationLabel.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/06.
//

import SwiftUI

struct IllustrationLabel: View {
    var illustrationPath: String
    @State var shouldDisplay: Bool = true

    var body: some View {
        ZStack(alignment: .center) {
            Group {
                if shouldDisplay {
                    if let image = UIImage(contentsOfFile: illustrationPath) {
                        Image(uiImage: image)
                            .resizable()
                    } else {
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
        .contentShape(Rectangle())
        .onAppear {
            shouldDisplay = true
        }
        .onDisappear {
            shouldDisplay = false
        }
        .transition(.opacity.animation(.snappy.speed(2)))
    }
}
