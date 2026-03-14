//
//  ProminentColor.swift
//  PicMate
//
//  Created by Claude on 2026/03/14.
//

import UIKit

enum ProminentColor {

    /// Calculates the most prominent saturated color from thumbnail image data.
    /// White and black pixels are ignored to find the most colorful/saturated color.
    /// Uses downsampled pixel data for performance.
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

        // Bucket colors to reduce noise (quantize to 8 levels per channel = 512 buckets)
        let shift = 5 // divide by 32
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

            // Skip near-white and near-black pixels
            if r > 220 && g > 220 && b > 220 { continue }
            if r < 35 && g < 35 && b < 35 { continue }

            // Calculate saturation to skip very desaturated (gray) pixels
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let chroma = maxC - minC
            // Skip grays (low chroma)
            if chroma < 25 { continue }

            let br = r >> shift
            let bg = g >> shift
            let bb = b >> shift
            let bucketIndex = br * 64 + bg * 8 + bb

            // Weight by saturation so more saturated colors are preferred
            let saturationWeight = chroma
            bucketCounts[bucketIndex] += saturationWeight
            bucketSumR[bucketIndex] += r * saturationWeight
            bucketSumG[bucketIndex] += g * saturationWeight
            bucketSumB[bucketIndex] += b * saturationWeight
        }

        // Find the bucket with the highest weighted count
        var bestBucket = -1
        var bestCount = 0
        for i in 0..<bucketCount {
            if bucketCounts[i] > bestCount {
                bestCount = bucketCounts[i]
                bestBucket = i
            }
        }

        guard bestBucket >= 0, bestCount > 0 else {
            // Fallback: no saturated color found, return gray
            return (r: 128, g: 128, b: 128)
        }

        // Average color of the best bucket
        let avgR = bucketSumR[bestBucket] / bestCount
        let avgG = bucketSumG[bestBucket] / bestCount
        let avgB = bucketSumB[bestBucket] / bestCount

        return (r: min(255, max(0, avgR)), g: min(255, max(0, avgG)), b: min(255, max(0, avgB)))
    }
}
