//
//  ViewPath.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation
import UIKit
import SwiftUI

enum ViewPath: Hashable {
    case collection
    case albums
    case illustrations
    case illustrationViewer(namespace: Namespace.ID)
    case album(album: Album)
    case more
    case moreAppIcon
    case moreDebug
    case moreOrphans(orphans: [String])
    case moreTroubleshooting
    case moreAttributions
}
