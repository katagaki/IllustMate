import Accelerate
import CoreGraphics
import UIKit
import Vision

enum EntityVision {

    struct Result: Sendable {
        let vector: [Float]
        let labels: [String]
        let visionRevision: Int
    }

    static let saliencyAreaCropThreshold: CGFloat = 0.6
    static let saliencyMinimumConfidence: Float = 0.5
    static let minimumCropFloor: CGFloat = 64.0
    static let maximumLabelCount = 3
    static let minimumLabelConfidence: Float = 0.1

    static func featurePrint(fromThumbnailData data: Data) -> Result? {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return nil }
        return featurePrint(from: cgImage)
    }

    static func featurePrint(from cgImage: CGImage) -> Result? {
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let printRequest = VNGenerateImageFeaturePrintRequest()
        let classifyRequest = VNClassifyImageRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([saliencyRequest, classifyRequest])

        let inputImage = croppedForSalientSubject(cgImage, using: saliencyRequest.results?.first)

        let printHandler = VNImageRequestHandler(cgImage: inputImage, options: [:])
        guard (try? printHandler.perform([printRequest])) != nil,
              let observation = printRequest.results?.first else { return nil }

        let vector = floats(from: observation)
        guard !vector.isEmpty else { return nil }

        let labels = dominantLabels(from: classifyRequest.results)
        return Result(vector: vector, labels: labels, visionRevision: printRequest.revision)
    }

    // MARK: - Saliency crop

    private static func croppedForSalientSubject(
        _ cgImage: CGImage, using observation: VNSaliencyImageObservation?
    ) -> CGImage {
        guard let salientObject = observation?.salientObjects?.max(by: { $0.confidence < $1.confidence }),
              salientObject.confidence >= saliencyMinimumConfidence else {
            return cgImage
        }

        let box = salientObject.boundingBox
        guard box.width > 0, box.height > 0,
              box.width * box.height < saliencyAreaCropThreshold else {
            return cgImage
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let cropRect = CGRect(
            x: box.minX * width,
            y: (1.0 - box.maxY) * height,
            width: box.width * width,
            height: box.height * height
        ).integral

        guard min(cropRect.width, cropRect.height) >= minimumCropFloor,
              let cropped = cgImage.cropping(to: cropRect) else {
            return cgImage
        }
        return cropped
    }

    // MARK: - Labels

    private static func dominantLabels(from observations: [VNClassificationObservation]?) -> [String] {
        guard let observations else { return [] }
        return observations
            .filter { $0.confidence >= minimumLabelConfidence }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maximumLabelCount)
            .map { $0.identifier }
    }

    // MARK: - Vector extraction

    private static func floats(from observation: VNFeaturePrintObservation) -> [Float] {
        let count = observation.elementCount
        let data = observation.data
        switch observation.elementType {
        case .float:
            guard data.count >= count * MemoryLayout<Float>.size else { return [] }
            return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self).prefix(count)) }
        case .double:
            guard data.count >= count * MemoryLayout<Double>.size else { return [] }
            return data.withUnsafeBytes { buffer in
                buffer.bindMemory(to: Double.self).prefix(count).map { Float($0) }
            }
        default:
            return []
        }
    }

    // MARK: - Similarity

    static func cosineDistance(_ lhs: [Float], _ rhs: [Float]) -> Float {
        let count = min(lhs.count, rhs.count)
        guard count > 0 else { return 2.0 }

        var dot: Float = 0
        var normLHS: Float = 0
        var normRHS: Float = 0
        vDSP_dotpr(lhs, 1, rhs, 1, &dot, vDSP_Length(count))
        vDSP_svesq(lhs, 1, &normLHS, vDSP_Length(count))
        vDSP_svesq(rhs, 1, &normRHS, vDSP_Length(count))

        let denominator = (normLHS.squareRoot() * normRHS.squareRoot())
        guard denominator > 0 else { return 2.0 }
        let similarity = dot / denominator
        return 1.0 - max(-1.0, min(1.0, similarity))
    }

    static func mean(of vectors: [[Float]]) -> [Float] {
        guard let first = vectors.first else { return [] }
        let length = first.count
        var accumulator = [Float](repeating: 0, count: length)
        var validCount: Float = 0
        for vector in vectors where vector.count == length {
            vDSP_vadd(accumulator, 1, vector, 1, &accumulator, 1, vDSP_Length(length))
            validCount += 1
        }
        guard validCount > 0 else { return [] }
        var divisor = validCount
        vDSP_vsdiv(accumulator, 1, &divisor, &accumulator, 1, vDSP_Length(length))
        return accumulator
    }
}
