//
//  Album.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import CoreTransferable
import CryptoKit
import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class Album: Identifiable, Hashable {
    var id: String
    var name: String
    var coverPhoto: Data?
    var parentAlbumID: String?
    var dateCreated: Date

    // Transient relationships (populated after fetch)
    var childAlbums: [Album]?
    var childIllustrations: [Illustration]?

    init(id: String = UUID().uuidString, name: String, coverPhoto: Data? = nil,
         parentAlbumID: String? = nil, dateCreated: Date = Date.now) {
        self.id = id
        self.name = name
        self.coverPhoto = coverPhoto
        self.parentAlbumID = parentAlbumID
        self.dateCreated = dateCreated
    }

    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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

    func representativePhotos() -> [Image?] {
        var imagesToReturn: [Image?] = []
        if let illustrations = childIllustrations {
            let sortedIllustrations = illustrations.sorted { lhs, rhs in
                lhs.dateAdded < rhs.dateAdded
            }
            let primaryImage: Illustration? = sortedIllustrations.count >= 1 ? sortedIllustrations[0] : nil
            let secondaryImage: Illustration? = sortedIllustrations.count >= 2 ? sortedIllustrations[1] : nil
            let tertiaryImage: Illustration? = sortedIllustrations.count >= 3 ? sortedIllustrations[2] : nil
            if let coverPhoto = coverPhoto, let coverImage = UIImage(data: coverPhoto) {
                imagesToReturn.append(Image(uiImage: coverImage))
            }
            if let primaryImage, let thumbnailData = primaryImage.thumbnailData,
               let thumbnail = UIImage(data: thumbnailData) {
                imagesToReturn.append(Image(uiImage: thumbnail))
            }
            if let secondaryImage, let thumbnailData = secondaryImage.thumbnailData,
               let thumbnail = UIImage(data: thumbnailData) {
                imagesToReturn.append(Image(uiImage: thumbnail))
            }
            if let tertiaryImage, let thumbnailData = tertiaryImage.thumbnailData,
               let thumbnail = UIImage(data: thumbnailData) {
                imagesToReturn.append(Image(uiImage: thumbnail))
            }
        }
        for _ in 0..<3 {
            imagesToReturn.append(nil)
        }
        imagesToReturn = Array(imagesToReturn[0..<3])
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
