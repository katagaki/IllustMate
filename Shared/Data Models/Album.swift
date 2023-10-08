//
//  Item.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation
import SwiftData
import UIKit

@Model
final class Album {
    var id = UUID().uuidString
    var name: String = ""
    var coverPhoto: Data?
    var childAlbums: [Album]? = []
    var childIllustrations: [Illustration]? = []
    @Relationship(deleteRule: .nullify, inverse: \Album.childAlbums) var parentAlbum: Album?
    var dateCreated: Date = Date.now

    init(name: String) {
        self.name = name
    }

    func albums() -> [Album] {
        return childAlbums?.sorted(by: { $0.name < $1.name }) ?? []
    }

    func illustrations() -> [Illustration] {
        return childIllustrations ?? []
    }

    func cover() -> UIImage {
        if let coverPhoto = coverPhoto,
           let uiImage = UIImage(data: coverPhoto) {
            return uiImage.scalePreservingAspectRatio(targetSize: CGSize(width: 60.0, height: 60.0))
        }
        return UIImage(named: "Album.Generic")!
    }

    func isInAlbum(_ album: Album?) -> Bool {
        if let album = album {
            return parentAlbum == album
        } else {
            return isNotInAnyAlbums()
        }
    }

    func isNotInAnyAlbums() -> Bool {
        parentAlbum == nil
    }

    func hasAlbums() -> Bool {
        return !albums().isEmpty
    }

    func hasIllustrations() -> Bool {
        return !illustrations().isEmpty
    }

    func addChildAlbum(_ album: Album) {
        childAlbums?.append(album)
    }

    func addChildIllustration(_ illustration: Illustration) {
        illustration.removeFromAlbum()
        childIllustrations?.append(illustration)
    }

    func addChildIllustrations(_ illustrations: [Illustration]) {
        illustrations.forEach { illustration in
            addChildIllustration(illustration)
        }
    }

    func removeChildIllustration(_ illustration: Illustration) {
        childIllustrations?.removeAll(where: { $0.id == illustration.id })
    }

    func removeChildIllustration(_ illustrations: [Illustration]) {
        illustrations.forEach { illustration in
            removeChildIllustration(illustration)
        }
    }

    static func makeCover(_ data: Data?) -> Data? {
        if let data = data, let sourceImage = UIImage(data: data) {
            return sourceImage.jpegThumbnail(of: 350.0)
        }
        return nil
    }
}
