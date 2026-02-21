//
//  Illustration.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import CoreTransferable
import Foundation
import UIKit
import UniformTypeIdentifiers

final class Illustration: Identifiable, Hashable, @unchecked Sendable {
    var id: String
    var name: String
    var containingAlbumID: String?
    var dateAdded: Date

    // Transient - loaded from database
    var thumbnailData: Data?

    // Transient - reference to containing album (may be nil)
    var containingAlbum: Album?

    init(id: String = UUID().uuidString, name: String, containingAlbumID: String? = nil,
         dateAdded: Date = Date.now) {
        self.id = id
        self.name = name
        self.containingAlbumID = containingAlbumID
        self.dateAdded = dateAdded
    }

    static func == (lhs: Illustration, rhs: Illustration) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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

struct IllustrationTransferable: Codable, Transferable {

    var id: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: IllustrationTransferable.self, contentType: .picture)
    }
}

extension UTType {
    static var picture: UTType { UTType(exportedAs: "com.tsubuzaki.IllustMate.Picture") }
}
