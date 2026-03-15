//
//  ProminentColor.swift
//  PicMate
//
//  Created by Claude on 2026/03/14.
//

import UIKit

enum ProminentColor {

    /// Calculates the most prominent color from thumbnail image data.
    /// White, black, and near-gray pixels are ignored.
    /// Returns the average color of the most common color bucket.
    static func calculate(from thumbnailData: Data) -> RGBColor? {
        guard let image = UIImage(data: thumbnailData),
              let cgImage = image.cgImage else { return nil }

        // Downsample to a small size for fast processing
        let sampleSize = 32
        let width = sampleSize
        let height = sampleSize
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow

        var pixelData = [UInt8](repeating: 0, count: totalBytes)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Quantize to 8 levels per channel (512 buckets)
        let shift = 5
        let bucketCount = 8 * 8 * 8
        var bucketCounts = [Int](repeating: 0, count: bucketCount)
        var bucketSumR = [Int](repeating: 0, count: bucketCount)
        var bucketSumG = [Int](repeating: 0, count: bucketCount)
        var bucketSumB = [Int](repeating: 0, count: bucketCount)

        let pixelCount = width * height
        for idx in 0..<pixelCount {
            let offset = idx * bytesPerPixel
            let red = Int(pixelData[offset])
            let green = Int(pixelData[offset + 1])
            let blue = Int(pixelData[offset + 2])
            let alpha = Int(pixelData[offset + 3])

            // Skip transparent pixels
            guard alpha > 128 else { continue }

            // Skip near-black using perceived luminance
            let luminance = 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
            if luminance < 40 { continue }

            // Skip near-white
            if luminance > 170 { continue }

            // Skip grays (low chroma)
            let maxC = max(red, green, blue)
            let minC = min(red, green, blue)
            if maxC - minC < 15 { continue }

            let bucketR = red >> shift
            let bucketG = green >> shift
            let bucketB = blue >> shift
            let bucketIndex = bucketR * 64 + bucketG * 8 + bucketB

            bucketCounts[bucketIndex] += 1
            bucketSumR[bucketIndex] += red
            bucketSumG[bucketIndex] += green
            bucketSumB[bucketIndex] += blue
        }

        // Find the bucket with the most pixels
        var bestBucket = -1
        var bestCount = 0
        for idx in 0..<bucketCount {
            if bucketCounts[idx] > bestCount {
                bestCount = bucketCounts[idx]
                bestBucket = idx
            }
        }

        guard bestBucket >= 0, bestCount > 0 else {
            return RGBColor(red: 128, green: 128, blue: 128)
        }

        // Average color of the most common bucket
        let avgR = bucketSumR[bestBucket] / bestCount
        let avgG = bucketSumG[bestBucket] / bestCount
        let avgB = bucketSumB[bestBucket] / bestCount

        return RGBColor(red: avgR, green: avgG, blue: avgB)
    }
}
