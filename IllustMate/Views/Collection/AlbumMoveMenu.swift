//
//  AlbumMoveMenu.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/14.
//

import SwiftData
import SwiftUI

struct AlbumMoveMenu: View {

    @Environment(\.modelContext) var modelContext
    var album: PhotoAlbum
    var onMoved: () -> Void

    var body: some View {
        // Moving albums between folders is not supported by PhotoKit
        Text("Moving albums not supported")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
