//
//  Thumbnail.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/10.
//

import Foundation
import SwiftData
import UIKit

@Model
final class Thumbnail {
    @Relationship(deleteRule: .cascade, inverse: \Illustration.cachedThumbnail) var illustration: Illustration?
    @Attribute(.externalStorage) var data: Data = Data()

    init(data: Data) {
        self.data = data
    }

    func image() -> UIImage? {
        return UIImage(data: data)
    }
}
