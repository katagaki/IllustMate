//
//  Album.swift
//  PicMate
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
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.coverPhoto?.count == rhs.coverPhoto?.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(coverPhoto?.count)
    }

    func identifiableString() -> String {
        "\(id)-\(coverPhoto?.count ?? 0)-\(childAlbumCount ?? 0)-\(childPicCount ?? 0)"
    }

    func albumCount() -> Int {
        return childAlbumCount ?? childAlbums?.count ?? 0
    }

    func picCount() -> Int {
        return childPicCount ?? childPics?.count ?? 0
    }

    func cover() -> UIImage {
        if let coverPhoto, let uiImage = UIImage(data: coverPhoto) {
            return uiImage
        }
        return UIImage(named: "Album.Generic")!
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
