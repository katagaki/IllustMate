//
//  UIImage.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/20.
//

import ImageIO
import UIKit

extension UIImage {
    /// Decodes image data directly at widget size using ImageIO, avoiding full-size bitmap allocation.
    static func downsampledForWidget(data: Data, maxDimension: CGFloat = 800) -> Data? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, downsampleOptions as CFDictionary
        ) else {
            return nil
        }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8)
    }
}
