//
//  ViewPath.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation

enum ViewPath: Hashable {
    case album(album: Album)
    case illustrationViewer(illustration: Illustration)
    case moreAttributions
}
