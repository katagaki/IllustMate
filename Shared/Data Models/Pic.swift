//
//  Pic.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import CoreTransferable
import Foundation
import UIKit
import UniformTypeIdentifiers

final class Pic: Identifiable, Hashable, @unchecked Sendable {
    var id: String
    var name: String
    var containingAlbumID: String?
    var dateAdded: Date
    var thumbnailData: Data?

    init(id: String = UUID().uuidString, name: String, containingAlbumID: String? = nil,
         dateAdded: Date = Date.now) {
        self.id = id
        self.name = name
        self.containingAlbumID = containingAlbumID
        self.dateAdded = dateAdded
    }

    static func == (lhs: Pic, rhs: Pic) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func identifiableString() -> String {
        let thumbnailSize = thumbnailData?.count ?? 0
        return "\(id)-\(thumbnailSize)"
    }

    func thumbnail() -> UIImage? {
        if let thumbnailData {
            return UIImage(data: thumbnailData)
        }
        return nil
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

struct PicTransferable: Codable, Identifiable, Transferable {

    var id: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: PicTransferable.self, contentType: .picture)
    }
}

struct PicCollectionTransferable: Codable, Transferable {

    var ids: [String]

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: PicCollectionTransferable.self, contentType: .pictureCollection)
    }
}

extension UTType {
    static var picture: UTType { UTType(exportedAs: "com.tsubuzaki.IllustMate.Pic") }
    static var pictureCollection: UTType { UTType(exportedAs: "com.tsubuzaki.IllustMate.PicCollection") }
}
