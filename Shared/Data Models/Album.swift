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
import SwiftUI
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

    static func makeCover(_ data: Data?) -> Data? {
        if let data, let sourceImage = UIImage(data: data) {
            return sourceImage.jpegThumbnail(of: 160.0)
        }
        return nil
    }

    func representativePhotos() -> [Image] {
        var imagesToReturn: [Image] = []
        let genericImage: Image = Image(uiImage: UIImage(named: "Album.Generic")!)
        if let illustrations = childIllustrations {
            let sortedIllustrations = illustrations.sorted { lhs, rhs in
                lhs.dateAdded < rhs.dateAdded
            }
            let primaryImage: Illustration? = sortedIllustrations.count >= 1 ? sortedIllustrations[0] : nil
            let secondaryImage: Illustration? = sortedIllustrations.count >= 2 ? sortedIllustrations[1] : nil
            let tertiaryImage: Illustration? = sortedIllustrations.count >= 3 ? sortedIllustrations[2] : nil
            if let coverPhoto = coverPhoto, let coverImage = UIImage(data: coverPhoto) {
                imagesToReturn.append(Image(uiImage: coverImage))
                if let primaryImage, let thumbnail = primaryImage.cachedThumbnail?.image() {
                    imagesToReturn.append(Image(uiImage: thumbnail))
                }
                if let secondaryImage, let thumbnail = secondaryImage.cachedThumbnail?.image() {
                    imagesToReturn.append(Image(uiImage: thumbnail))
                }
            } else {
                if let primaryImage, let thumbnail = primaryImage.cachedThumbnail?.image() {
                    imagesToReturn.append(Image(uiImage: thumbnail))
                }
                if let secondaryImage, let thumbnail = secondaryImage.cachedThumbnail?.image() {
                    imagesToReturn.append(Image(uiImage: thumbnail))
                }
                if let tertiaryImage, let thumbnail = tertiaryImage.cachedThumbnail?.image() {
                    imagesToReturn.append(Image(uiImage: thumbnail))
                }
            }
        }
        if imagesToReturn.count < 3 {
            for _ in imagesToReturn.count...3 {
                imagesToReturn.append(genericImage)
            }
        }
        return imagesToReturn
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
