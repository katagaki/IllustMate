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

        // Bucket in HSB space: 24 hue bins × 4 saturation bins × 4 brightness bins = 384 buckets
        // HSB bucketing groups perceptually similar colors better than RGB
        let hueBins = 24
        let satBins = 4
        let briBins = 4
        let bucketCount = hueBins * satBins * briBins
        var bucketWeights = [Double](repeating: 0, count: bucketCount)
        var bucketSumR = [Double](repeating: 0, count: bucketCount)
        var bucketSumG = [Double](repeating: 0, count: bucketCount)
        var bucketSumB = [Double](repeating: 0, count: bucketCount)

        let pixelCount = width * height
        for i in 0..<pixelCount {
            let offset = i * bytesPerPixel
            let r = Int(pixelData[offset])
            let g = Int(pixelData[offset + 1])
            let b = Int(pixelData[offset + 2])
            let a = Int(pixelData[offset + 3])

            // Skip transparent pixels
            guard a > 128 else { continue }

            // Skip near-black pixels
            if r < 30 && g < 30 && b < 30 { continue }

            // Skip near-white using perceived luminance
            // This catches off-whites like (200, 210, 205) that RGB threshold misses
            let luminance = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
            if luminance > 200 { continue }

            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let chroma = maxC - minC

            // Skip grays/desaturated pixels entirely — they should never contribute
            if chroma < 15 { continue }

            // Convert to HSB
            let rf = Double(r) / 255.0
            let gf = Double(g) / 255.0
            let bf = Double(b) / 255.0
            let maxF = Double(maxC) / 255.0
            let chromaF = Double(chroma) / 255.0

            // Hue calculation (0.0 - 1.0)
            let hue: Double
            if maxC == r {
                hue = fmod((gf - bf) / chromaF, 6.0) / 6.0
            } else if maxC == g {
                hue = ((bf - rf) / chromaF + 2.0) / 6.0
            } else {
                hue = ((rf - gf) / chromaF + 4.0) / 6.0
            }
            let normalizedHue = hue < 0 ? hue + 1.0 : hue

            // Saturation (0.0 - 1.0)
            let saturation = maxF > 0 ? chromaF / maxF : 0.0

            // Brightness (0.0 - 1.0)
            let brightness = maxF

            let hBin = min(Int(normalizedHue * Double(hueBins)), hueBins - 1)
            let sBin = min(Int(saturation * Double(satBins)), satBins - 1)
            let bBin = min(Int(brightness * Double(briBins)), briBins - 1)
            let bucketIndex = hBin * (satBins * briBins) + sBin * briBins + bBin

            // s^5 weighting: a pixel at s=0.8 gets ~330× more weight than s=0.2
            // This ensures even a small patch of vivid color dominates over large
            // areas of muted/washed-out pixels
            let s2 = saturation * saturation
            let satWeight = s2 * s2 * saturation  // s^5
            let briWeight = 1.0 - abs(brightness - 0.6) * 0.5
            let weight = satWeight * briWeight

            bucketWeights[bucketIndex] += weight
            bucketSumR[bucketIndex] += rf * weight
            bucketSumG[bucketIndex] += gf * weight
            bucketSumB[bucketIndex] += bf * weight
        }

        // Find the bucket with the highest weighted count
        var bestBucket = -1
        var bestWeight = 0.0
        for i in 0..<bucketCount {
            if bucketWeights[i] > bestWeight {
                bestWeight = bucketWeights[i]
                bestBucket = i
            }
        }

        guard bestBucket >= 0, bestWeight > 0 else {
            // Fallback: no saturated color found, return gray
            return (r: 128, g: 128, b: 128)
        }

        // Weighted average color of the best bucket
        let avgR = Int(round(bucketSumR[bestBucket] / bestWeight * 255.0))
        let avgG = Int(round(bucketSumG[bestBucket] / bestWeight * 255.0))
        let avgB = Int(round(bucketSumB[bestBucket] / bestWeight * 255.0))

        return (r: min(255, max(0, avgR)), g: min(255, max(0, avgG)), b: min(255, max(0, avgB)))
    }
}
