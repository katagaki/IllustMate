//
//  ViewPath.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation

enum ViewPath: Hashable {
    case collection
    case illustrations
    case album(album: Album)
    case importer
    case more
    case moreDataManagement
    case moreFileManagement
    case moreDebug
    case moreOrphans(orphans: [String])
    case moreTroubleshooting
    case moreAttributions
}
