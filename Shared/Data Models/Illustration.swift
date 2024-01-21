//
//  Illustration.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import CoreTransferable
import Foundation
import SwiftData
import UIKit
import UniformTypeIdentifiers

@Model
final class Illustration {
    var id = UUID().uuidString
    var name: String = ""
    @Relationship(deleteRule: .nullify, inverse: \Album.childIllustrations) var containingAlbum: Album?
    @Relationship(deleteRule: .cascade) var cachedThumbnail: Thumbnail?
    var dateAdded: Date = Date.now

    init(name: String, data: Data) {
        self.name = name
        self.dateAdded = .now
        FileManager.default.createFile(atPath: illustrationPath(), contents: data)
    }

    func illustrationPath() -> String {
        return illustrationsFolder.appendingPathComponent(id).path(percentEncoded: false)
    }

    func illustrationPathWhenUbiquitousFileNotDownloaded() -> String {
        return illustrationsFolder.appendingPathComponent(".\(id).icloud").path(percentEncoded: false)
    }

    func thumbnail() -> UIImage? {
        return cachedThumbnail?.image()
    }

    func generateThumbnail() {
        if let data = try? Data(contentsOf: URL(filePath: illustrationPath())),
           let thumbnailData = Illustration.makeThumbnail(data) {
            let thumbnail = Thumbnail(data: thumbnailData)
            cachedThumbnail = thumbnail
        }
    }

    func prepareForDeletion() {
        try? FileManager.default.removeItem(atPath: illustrationPath())
    }

    static func newFilename() -> String {
        let date = Date.now
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmssSSSS"
        return "PIC_" + dateFormatter.string(from: date)
    }

    static func makeThumbnail(_ data: Data?) -> Data? {
        if let data, let sourceImage = UIImage(data: data) {
            return sourceImage.jpegThumbnail(of: 120.0)
        }
        return nil
    }
}

struct IllustrationTransferable: Codable, Transferable {

    var id: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: IllustrationTransferable.self, contentType: .picture)
    }
}

extension UTType {
    static var picture: UTType { UTType(exportedAs: "com.tsubuzaki.IllustMate.Picture") }
}
