//
//  Item.swift
//  IllustMate
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
    @Relationship(deleteRule: .cascade, inverse: \Album.childAlbums) var parentAlbum: Album?
    var dateCreated: Date = Date.now

    init(name: String, dateCreated: Date) {
        self.name = name
        self.dateCreated = dateCreated
    }

    func albums() -> [Album] {
        return childAlbums ?? []
    }

    func illustrations() -> [Illustration] {
        return childIllustrations ?? []
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

    func moveChildIllustration(_ illustration: Illustration) {
        illustration.containingAlbums?.forEach({ album in
            album.removeChildIllustration(illustration)
        })
        childIllustrations?.append(illustration)
    }

    func moveChildIllustrations(_ illustrations: [Illustration]) {
        illustrations.forEach { illustration in
            illustration.containingAlbums?.forEach({ album in
                album.removeChildIllustration(illustration)
            })
        }
        childIllustrations?.append(contentsOf: illustrations)
    }

    func removeChildIllustration(_ illustration: Illustration) {
        childIllustrations?.removeAll(where: { $0.id == illustration.id })
    }

    static func makeCover(_ data: Data?) -> Data? {
        if let data = data, let sourceImage = UIImage(data: data) {
            let shortSideLength = min(sourceImage.size.width, sourceImage.size.height)
            let xOffset = (sourceImage.size.width - shortSideLength) / 2.0
            let yOffset = (sourceImage.size.height - shortSideLength) / 2.0
            let cropRect = CGRect(x: xOffset, y: yOffset, width: shortSideLength, height: shortSideLength)
            let imageRendererFormat = sourceImage.imageRendererFormat
            imageRendererFormat.opaque = false
            let croppedImage = UIGraphicsImageRenderer(size: cropRect.size,
                                                             format: imageRendererFormat).image { _ in
                sourceImage.draw(in: CGRect(origin: CGPoint(x: -xOffset, y: -yOffset), size: sourceImage.size))
            }.cgImage!
            return UIImage(cgImage: croppedImage).preparingThumbnail(of: CGSize(width: 500.0, height: 500.0))?.pngData()
        }
        return nil
    }
}
