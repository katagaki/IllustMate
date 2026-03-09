//
//  DHash.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/09.
//

import UIKit

enum DHash {

    /// Computes a 64-bit difference hash for the given image.
    /// Resizes to 9x8 grayscale, then compares each pixel to its right neighbor.
    static func compute(from image: UIImage) -> UInt64? {
        guard let cgImage = image.cgImage else { return nil }

        let width = 9
        let height = 8

        var pixelBuffer = [UInt8](repeating: 0, count: width * height)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixelBuffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        for row in 0..<height {
            for col in 0..<(width - 1) {
                let leftPixel = pixelBuffer[row * width + col]
                let rightPixel = pixelBuffer[row * width + col + 1]
                hash = (hash << 1) | (leftPixel > rightPixel ? 1 : 0)
            }
        }

        return hash
    }

    /// Hamming distance between two hashes (number of differing bits).
    static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }
}
