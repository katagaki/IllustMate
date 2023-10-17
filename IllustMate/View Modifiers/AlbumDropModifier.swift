//
//  AlbumDropModifier.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/17.
//

import SwiftUI

struct AlbumDropModifier: ViewModifier {

    var onDrop: ((Drop, Album) -> Void)?
    var album: Album

    init(onDrop: ((Drop, Album) -> Void)? = nil, album: Album) {
        self.onDrop = onDrop
        self.album = album
    }

    func body(content: Content) -> some View {
        content
            .dropDestination(for: Drop.self) { items, _ in
                for item in items {
                    if let onDrop {
                        onDrop(item, album)
                    }
                }
                return true
            }
    }
}

extension View {
    func albumDropDestination(onDrop: ((Drop, Album) -> Void)? = nil, album: Album) -> some View {
        modifier(AlbumDropModifier(onDrop: onDrop, album: album))
    }
}
