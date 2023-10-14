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
        let shortSideLength = min(self.size.width, self.size.height)
        let xOffset = (self.size.width - shortSideLength) / 2.0
        let yOffset = (self.size.height - shortSideLength) / 2.0
        let cropRect = CGRect(x: xOffset, y: yOffset, width: shortSideLength, height: shortSideLength)
        let imageRendererFormat = self.imageRendererFormat
        imageRendererFormat.opaque = false
        let croppedImage = UIGraphicsImageRenderer(size: cropRect.size,
                                                         format: imageRendererFormat).image { _ in
            self.draw(in: CGRect(origin: CGPoint(x: -xOffset, y: -yOffset),
                                        size: self.size))
        }.cgImage!
        if let scaledImage = UIImage(cgImage: croppedImage)
            .scaleImage(toSize: CGSize(width: length, height: length)) {
            return scaledImage.jpegData(compressionQuality: 0.7)
        }
        return nil
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

    // Adapted from: https://stackoverflow.com/questions/31966885/resize-uiimage-to-200x200pt-px
    func scaleImage(toSize newSize: CGSize) -> UIImage? {
        var newImage: UIImage?
        let newRect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height).integral
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        if let context = UIGraphicsGetCurrentContext(), let cgImage = self.cgImage {
            context.interpolationQuality = .high
            let flipVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: newSize.height)
            context.concatenate(flipVertical)
            context.draw(cgImage, in: newRect)
            if let img = context.makeImage() {
                newImage = UIImage(cgImage: img)
            }
            UIGraphicsEndImageContext()
        }
        return newImage
    }
}
