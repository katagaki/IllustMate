//
//  UIImage.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import UIKit

extension UIImage {
    func resizedForWidget(maxDimension: CGFloat = 800) -> Data? {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        guard let resized = preparingThumbnail(of: targetSize) else { return nil }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
