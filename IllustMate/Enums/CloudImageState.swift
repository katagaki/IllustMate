//
//  CloudImageState.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/10.
//

import Foundation

enum CloudImageState: Int {
    case notReadyForDisplay = 0
    case downloading = 1
    case downloaded = 2
    case readyForDisplay = 3
    case hidden = 4
}
