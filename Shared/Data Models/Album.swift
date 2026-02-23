//
//  Album.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import CoreTransferable
import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class Album: Identifiable, Hashable, @unchecked Sendable {
    var id: String
    var name: String
    var coverPhoto: Data?
    var parentAlbumID: String?
    var dateCreated: Date

    // Transient relationships (populated after fetch)
    var childAlbums: [Album]?
    var childPics: [Pic]?

    // Lightweight counts (populated without loading children)
    var childAlbumCount: Int?
    var childPicCount: Int?

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
        let coverSize = coverPhoto?.count ?? 0
        return "\(id)-\(coverSize)-\(albumCount())-\(picCount())"
    }

    func albums() -> [Album] {
        return childAlbums?.sorted(by: { $0.name < $1.name }) ?? []
    }

    func pics() -> [Pic] {
        return childPics ?? []
    }

    func albumCount() -> Int {
        return childAlbumCount ?? childAlbums?.count ?? 0
    }

    func picCount() -> Int {
        return childPicCount ?? childPics?.count ?? 0
    }

    func cover() -> UIImage {
        if let coverPhoto, let uiImage = UIImage(data: coverPhoto) {
            return uiImage.scalePreservingAspectRatio(targetSize: CGSize(width: 60.0, height: 60.0))
        }
        return UIImage(named: "Album.Generic")!
    }

    static func makeCover(_ data: Data?) -> Data? {
        if let data, let sourceImage = UIImage(data: data) {
            return sourceImage.jpegThumbnail(of: 160.0)
        }
        return nil
    }

    func representativePhotos() -> [Image?] {
        var imagesToReturn: [Image?] = []
        if let pics = childPics {
            let sortedPics = pics.sorted { lhs, rhs in
                lhs.dateAdded < rhs.dateAdded
            }
            let primaryImage: Pic? = sortedPics.count >= 1 ? sortedPics[0] : nil
            let secondaryImage: Pic? = sortedPics.count >= 2 ? sortedPics[1] : nil
            let tertiaryImage: Pic? = sortedPics.count >= 3 ? sortedPics[2] : nil
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
