//
//  Item.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import CoreTransferable
import CryptoKit
import Foundation
import SwiftData
import UIKit
import UniformTypeIdentifiers

@Model
final class Album {
    var id = UUID().uuidString
    var name: String = ""
    var coverPhoto: Data?
    @Relationship(deleteRule: .cascade) var childAlbums: [Album]? = []
    var childIllustrations: [Illustration]? = []
    @Relationship(deleteRule: .nullify, inverse: \Album.childAlbums) var parentAlbum: Album?
    var dateCreated: Date = Date.now

    init(name: String) {
        self.name = name
    }

    func identifiableString() -> String {
        return "\(id)-\(coverHash())-\(albumCount())-\(illustrationCount())"
    }

    func albums() -> [Album] {
        return childAlbums?.sorted(by: { $0.name < $1.name }) ?? []
    }

    func illustrations() -> [Illustration] {
        return childIllustrations ?? []
    }

    func albumCount() -> Int {
        return childAlbums?.count ?? 0
    }

    func illustrationCount() -> Int {
        return childIllustrations?.count ?? 0
    }

    func cover() -> UIImage {
        if let coverPhoto, let uiImage = UIImage(data: coverPhoto) {
            return uiImage.scalePreservingAspectRatio(targetSize: CGSize(width: 60.0, height: 60.0))
        }
        return UIImage(named: "Album.Generic")!
    }

    func coverHash() -> String {
        if let coverPhoto {
            return SHA256.hash(data: coverPhoto).compactMap { String(format: "%02x", $0) }.joined()
        } else {
            return ""
        }
    }

    func isInAlbum(_ album: Album?) -> Bool {
        if let album {
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

    func addChildAlbums(_ albums: [Album]) {
        albums.forEach { album in
            addChildAlbum(album)
        }
    }

    func addChildIllustration(_ illustration: Illustration) {
//        illustration.removeFromAlbum()
        childIllustrations?.append(illustration)
    }

    func addChildIllustrations(_ illustrations: [Illustration]) {
        for illustration in illustrations {
            addChildIllustration(illustration)
        }
    }

    func removeFromAlbum() {
        parentAlbum = nil
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
        if let data, let sourceImage = UIImage(data: data) {
            return sourceImage.jpegThumbnail(of: 160.0)
        }
        return nil
    }
}

struct AlbumTransferable: Codable, Transferable {

    var id: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: AlbumTransferable.self, contentType: .album)
    }
}

extension UTType {
    static var album: UTType { UTType(exportedAs: "com.tsubuzaki.IllustMate.Album") }
}
