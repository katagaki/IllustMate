//
//  UIImage.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/04.
//

import Foundation
import UIKit

// Adapted from: https://www.advancedswift.com/resize-uiimage-no-stretching-swift/
extension UIImage {
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
}
