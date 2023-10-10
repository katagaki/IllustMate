//
//  Illustration.swift
//  PicMate
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

    func thumbnailPath() -> String {
        return thumbnailsFolder.appendingPathComponent(id).path(percentEncoded: false)
    }

    func thumbnailPathWhenUbiquitousFileNotDownloaded() -> String {
        return thumbnailsFolder.appendingPathComponent(".\(id).icloud").path(percentEncoded: false)
    }

    func isInAlbum(_ album: Album?) -> Bool {
        if let album {
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
        if let data, let sourceImage = UIImage(data: data) {
            return sourceImage.jpegThumbnail(of: 150.0)
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
