//
//  ViewPath.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation

enum ViewPath: Hashable {
    case collection
    case album(album: Album)
    case importer
    case more
    case moreAttributions
}
