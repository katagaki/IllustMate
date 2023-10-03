//
//  Illustration.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation
import SwiftData
import UIKit

@Model
final class Illustration {
    var id = UUID().uuidString
    var name: String = ""
    var data: IllustrationData?
    var thumbnail: Data = Data()
    var format: IllustrationFormat = IllustrationFormat.unknown
    @Relationship(deleteRule: .nullify, inverse: \Album.childIllustrations) var containingAlbums: [Album]? = []
    var dateAdded: Date = Date.now

    init(name: String, data: Data) {
        self.name = name
        self.data = IllustrationData(id: self.id, data: data)
        if let thumbnailData = Illustration.makeThumbnail(data) {
            thumbnail = thumbnailData
        }
        self.dateAdded = .now
    }

    func image() -> UIImage? {
        if let data = data {
            return UIImage(data: data.data)
        }
        return nil
    }

    static func makeThumbnail(_ data: Data?) -> Data? {
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
            return UIImage(cgImage: croppedImage).preparingThumbnail(of: CGSize(width: 300.0, height: 300.0))?.pngData()
        }
        return nil
    }
}

enum IllustrationFormat: Codable {
    case unknown
    case png
    case jpg
    case heic
}
