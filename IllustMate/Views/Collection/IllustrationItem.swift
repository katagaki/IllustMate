//
//  IllustrationItem.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import SwiftUI

struct IllustrationItem: View {

    var illustration: Illustration

    var body: some View {
        if let uiImage = UIImage(data: illustration.thumbnail) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(1.0, contentMode: .fill)
        } else if let uiImage = UIImage(data: illustration.data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(1.0, contentMode: .fill)
        }
    }
}
