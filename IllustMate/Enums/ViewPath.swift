//
//  ViewPath.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation

enum ViewPath: Hashable {
    case collection
    case albums
    case illustrations
    case album(album: Album)
    case importer
    case more
    case moreDataManagement
    case moreDataAlbums(albums: [Album])
    case moreDataIllustrations(illustrations: [Illustration])
    case moreFileManagement
    case moreAppIcon
    case moreDebug
    case moreOrphans(orphans: [String])
    case moreTroubleshooting
    case moreAttributions
}
