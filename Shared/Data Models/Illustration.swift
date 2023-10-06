//
//  Illustration.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

@Model
final class Illustration {
    var id = UUID().uuidString
    var name: String = ""
    @Relationship(deleteRule: .nullify, inverse: \Album.childIllustrations) var containingAlbum: Album?
    var dateAdded: Date = Date.now

    init(name: String, data: Data) {
        self.name = name
        self.dateAdded = .now
        FileManager.default.createFile(atPath: illustrationPath(), contents: data)
        if let thumbnailData = Illustration.makeThumbnail(data) {
            FileManager.default.createFile(atPath: thumbnailPath(), contents: thumbnailData)
        }
    }

    func illustrationPath() -> String {
        return illustrationsFolder.appendingPathComponent(id).path(percentEncoded: false)
    }

    func thumbnailPath() -> String {
        return thumbnailsFolder.appendingPathComponent(id).path(percentEncoded: false)
    }

    func isInAlbum(_ album: Album?) -> Bool {
        if let album = album {
            return containingAlbum?.id ?? "" == album.id
        }
        return true
    }

    func addToAlbum(_ album: Album) {
        containingAlbum = album
    }

    func removeFromAlbum() {
        containingAlbum = nil
    }

    func prepareForDeletion() {
        try? FileManager.default.removeItem(atPath: illustrationPath())
        try? FileManager.default.removeItem(atPath: thumbnailPath())
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
            return UIImage(cgImage: croppedImage)
                .preparingThumbnail(of: CGSize(width: 200.0, height: 200.0))?
                .jpegData(compressionQuality: 1.0)
        }
        return nil
    }
}

struct IllustrationTransferable: Codable, Transferable {

    var id: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: IllustrationTransferable.self, contentType: .image)
        ProxyRepresentation(exporting: \.id)
    }
}
