//
//  UIImage.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/04.
//

import Foundation
import UIKit

extension UIImage {

    func data() -> Data {
        if let data = pngData() {
            return data
        } else if let data = jpegData(compressionQuality: 1.0) {
            return data
        } else if let data = heicData() {
            return data
        }
        return Data()
    }

    func jpegThumbnail(of length: Double) -> Data? {
        let scaleFactor = length / max(self.size.width, self.size.height)
        let targetSize = CGSize(width: self.size.width * scaleFactor,
                                height: self.size.height * scaleFactor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0
        format.opaque = false
        let scaledImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return scaledImage.jpegData(compressionQuality: 0.7)
    }

    // Adapted from: https://www.advancedswift.com/resize-uiimage-no-stretching-swift/
    func scalePreservingAspectRatio(targetSize: CGSize) -> UIImage {
        let scaleFactor = min(targetSize.width / size.width, targetSize.height / size.height)
        let scaledImageSize = CGSize(width: size.width * scaleFactor,
                                     height: size.height * scaleFactor)
        let renderer = UIGraphicsImageRenderer(size: scaledImageSize)
        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledImageSize))
        }
        return scaledImage
    }

    func scaleImage(toSize newSize: CGSize) -> UIImage? {
        let newRect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0
        return UIGraphicsImageRenderer(size: newRect.size, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
