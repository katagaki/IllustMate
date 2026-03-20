//
//  AsyncPhotosFolderCover.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import Photos
import SwiftUI

extension AlbumCover {

    /// Album cover (Photos library folder)
    struct AsyncPhotosFolderCover: View {

        var folder: PHCollectionList
        var length: CGFloat?

        var body: some View {
            AlbumCover(name: folder.localizedTitle ?? "",
                       length: length,
                       picCount: 0,
                       albumCount: PHCollection.fetchCollections(in: folder, options: nil).count)
        }
    }
}
