//
//  Illustration.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Foundation
import SwiftData
import UIKit

@Model
final class Illustration {
    var id = UUID().uuidString
    var name: String = ""
    var data: Data = Data()
    var thumbnail: Data = Data()
    var format: IllustrationFormat = IllustrationFormat.unknown
    @Relationship(deleteRule: .nullify, inverse: \Album.childIllustrations) var containingAlbums: [Album]? = []
    var dateAdded: Date = Date.now

    init(name: String, image: UIImage) {
        self.name = name
        if let data = image.pngData() {
            self.data = data
            self.format = .png
        } else if let data = image.jpegData(compressionQuality: 1.0) {
            self.data = data
            self.format = .jpg
        } else if let data = image.heicData() {
            self.data = data
            self.format = .heic
        }
        if let image = UIImage(data: data)?
            .preparingThumbnail(of: CGSize(width: 200.0, height: 200.0)) {
            thumbnail = image.pngData() ?? Data()
        }
        self.dateAdded = .now
    }

    func image() -> UIImage? {
        return UIImage(data: data)
    }
}

enum IllustrationFormat: Codable {
    case unknown
    case png
    case jpg
    case heic
}
