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
    var data: Data = Data()
    var thumbnail: Data = Data()
    var format: IllustrationFormat = IllustrationFormat.unknown
    @Relationship(deleteRule: .nullify, inverse: \Album.childIllustrations) var containingAlbums: [Album]? = []
    var dateAdded: Date = Date.now

    init(name: String, image: UIImage) {
        self.name = name
        if let data = image.pngData() {
            self.data = data
            self.format = .png
        } else if let data = image.jpegData(compressionQuality: 1.0) {
            self.data = data
            self.format = .jpg
        } else if let data = image.heicData() {
            self.data = data
            self.format = .heic
        }
        if let thumbnailData = Illustration.makeThumbnail(data) {
            thumbnail = thumbnailData
        }
        self.dateAdded = .now
    }

    func image() -> UIImage? {
        return UIImage(data: data)
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
            let length = 300
            let context = CGContext(data: nil, width: length, height: length, bitsPerComponent: 8,
                                    bytesPerRow: length * croppedImage.bitsPerPixel / 8,
                                    space: croppedImage.colorSpace!,
                                    bitmapInfo: croppedImage.bitmapInfo.rawValue)!
            context.interpolationQuality = .high
            context.draw(croppedImage, in: CGRect(origin: CGPoint.zero,
                                                        size: CGSize(width: length, height: length)))
            return context.makeImage().flatMap { UIImage(cgImage: $0) }?.pngData()
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
