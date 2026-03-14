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
    static func calculate(from thumbnailData: Data) -> (r: Int, g: Int, b: Int)? {
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
        for i in 0..<pixelCount {
            let offset = i * bytesPerPixel
            let r = Int(pixelData[offset])
            let g = Int(pixelData[offset + 1])
            let b = Int(pixelData[offset + 2])
            let a = Int(pixelData[offset + 3])

            // Skip transparent pixels
            guard a > 128 else { continue }

            // Skip near-black using perceived luminance
            let luminance = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
            if luminance < 40 { continue }

            // Skip near-white
            if luminance > 170 { continue }

            // Skip grays (low chroma)
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            if maxC - minC < 15 { continue }

            let br = r >> shift
            let bg = g >> shift
            let bb = b >> shift
            let bucketIndex = br * 64 + bg * 8 + bb

            bucketCounts[bucketIndex] += 1
            bucketSumR[bucketIndex] += r
            bucketSumG[bucketIndex] += g
            bucketSumB[bucketIndex] += b
        }

        // Find the bucket with the most pixels
        var bestBucket = -1
        var bestCount = 0
        for i in 0..<bucketCount {
            if bucketCounts[i] > bestCount {
                bestCount = bucketCounts[i]
                bestBucket = i
            }
        }

        guard bestBucket >= 0, bestCount > 0 else {
            return (r: 128, g: 128, b: 128)
        }

        // Average color of the most common bucket
        let avgR = bucketSumR[bestBucket] / bestCount
        let avgG = bucketSumG[bestBucket] / bestCount
        let avgB = bucketSumB[bestBucket] / bestCount

        return (r: avgR, g: avgG, b: avgB)
    }
}
