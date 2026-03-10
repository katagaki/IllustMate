//
//  PictureInPictureManager.swift
//  PicMate
//
//  Created on 2026/03/10.
//

import AVKit
import CoreMedia
import SwiftUI

@MainActor @Observable
class PictureInPictureManager: NSObject {

    var isActive: Bool = false

    @ObservationIgnored var onRestore: (@MainActor () -> Void)?
    @ObservationIgnored private var pipController: AVPictureInPictureController?
    @ObservationIgnored private(set) var bufferView = SampleBufferPiPView()

    var isPossible: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    func setup() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }

        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: bufferView.sampleBufferDisplayLayer,
            playbackDelegate: self
        )
        pipController = AVPictureInPictureController(contentSource: source)
        pipController?.delegate = self
        pipController?.requiresLinearPlayback = true
    }

    func start(with image: UIImage, restore: @escaping @MainActor () -> Void) {
        guard let pipController, let sampleBuffer = createSampleBuffer(from: image) else { return }

        onRestore = restore

        bufferView.sampleBufferDisplayLayer.flush()
        bufferView.sampleBufferDisplayLayer.enqueue(sampleBuffer)

        UIApplication.shared.isIdleTimerDisabled = true

        pipController.startPictureInPicture()
    }

    func stop() {
        pipController?.stopPictureInPicture()
    }

    private func didStop() {
        isActive = false
        onRestore = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Sample Buffer Creation

    private func createSampleBuffer(from image: UIImage) -> CMSampleBuffer? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA, attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
                | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescriptionOut: &formatDescription
        )
        guard let format = formatDescription else { return nil }

        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime.positiveInfinity,
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )

        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PictureInPictureManager: AVPictureInPictureControllerDelegate {

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor in
            isActive = true
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor in
            didStop()
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            onRestore?()
        }
        completionHandler(true)
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

extension PictureInPictureManager: AVPictureInPictureSampleBufferPlaybackDelegate {

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        setPlaying playing: Bool
    ) {
        // No-op: static image, no playback
    }

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 1))
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> Bool {
        false
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {
        // No-op
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion: @escaping () -> Void
    ) {
        completion()
    }
}

// MARK: - Sample Buffer Display View

class SampleBufferPiPView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer
    }
}

// MARK: - SwiftUI Wrapper

struct PictureInPictureLayerView: UIViewRepresentable {
    let pipManager: PictureInPictureManager

    func makeUIView(context: UIViewRepresentableContext<PictureInPictureLayerView>) -> UIView {
        let container = UIView()
        let bufferView = pipManager.bufferView
        bufferView.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        bufferView.isHidden = true
        container.addSubview(bufferView)
        return container
    }

    func updateUIView(_ uiView: UIView,
                      context: UIViewRepresentableContext<PictureInPictureLayerView>) {}
}
