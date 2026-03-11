//
//  PictureInPictureManager.swift
//  PicMate
//
//  Created on 2026/03/10.
//

import AVFoundation
import AVKit
import CoreMedia
import SwiftUI

@MainActor @Observable
class PictureInPictureManager: NSObject {

    var isActive: Bool = false

    @ObservationIgnored var onRestore: (@MainActor () -> Void)?
    @ObservationIgnored private var pipController: AVPictureInPictureController?
    @ObservationIgnored private var player: AVQueuePlayer?
    @ObservationIgnored private var playerLooper: AVPlayerLooper?
    @ObservationIgnored private(set) var playerLayer = AVPlayerLayer()

    var isPossible: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    func setup() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }

        let player = AVQueuePlayer()
        player.isMuted = true
        player.allowsExternalPlayback = false
        self.player = player

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
    }

    /// Called by the layer view once the player layer is attached to the window.
    func layerDidMoveToWindow() {
        guard pipController == nil, player != nil else { return }
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self
        pipController?.requiresLinearPlayback = true
    }

    func start(with image: UIImage, restore: @escaping @MainActor () -> Void) {
        guard pipController != nil, player != nil else { return }

        onRestore = restore

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            debugPrint("PiP: Failed to configure audio session: \(error)")
        }

        Task.detached(priority: .userInitiated) {
            guard let videoURL = Self.createVideo(from: image) else { return }
            await MainActor.run {
                guard let pipController = self.pipController,
                      let player = self.player else { return }
                let asset = AVAsset(url: videoURL)
                let item = AVPlayerItem(asset: asset)
                // Loop the short video so PiP stays alive indefinitely.
                player.removeAllItems()
                self.playerLooper = AVPlayerLooper(player: player, templateItem: item)
                player.play()
                UIApplication.shared.isIdleTimerDisabled = true
                pipController.startPictureInPicture()
            }
        }
    }

    func stop() {
        pipController?.stopPictureInPicture()
    }

    private func didStop() {
        isActive = false
        onRestore = nil
        player?.pause()
        player?.removeAllItems()
        playerLooper = nil
        UIApplication.shared.isIdleTimerDisabled = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            debugPrint("PiP: Failed to deactivate audio session: \(error)")
        }
    }

    // MARK: - Video Creation

    /// Writes a single-frame video (~1 s) from the given image to a temporary file.
    private nonisolated static func createVideo(from image: UIImage) -> URL? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        // Dimensions must be even for H.264.
        let evenWidth = width % 2 == 0 ? width : width - 1
        let evenHeight = height % 2 == 0 ? height : height - 1

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            return nil
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: evenWidth,
            AVVideoHeightKey: evenHeight
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: evenWidth,
                kCVPixelBufferHeightKey as String: evenHeight
            ]
        )

        writer.add(writerInput)

        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)

        guard let pixelBuffer = createPixelBuffer(from: cgImage,
                                                  width: evenWidth,
                                                  height: evenHeight) else {
            writer.cancelWriting()
            return nil
        }

        // Write two identical frames to produce a ~1-second video.
        let frameDuration = CMTime(value: 1, timescale: 2)
        adaptor.append(pixelBuffer, withPresentationTime: .zero)
        adaptor.append(pixelBuffer, withPresentationTime: frameDuration)

        writerInput.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()

        return writer.status == .completed ? outputURL : nil
    }

    private nonisolated static func createPixelBuffer(
        from cgImage: CGImage, width: Int, height: Int
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
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
        return buffer
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

// MARK: - SwiftUI Wrapper

struct PictureInPictureLayerView: UIViewRepresentable {
    let pipManager: PictureInPictureManager

    func makeUIView(context: UIViewRepresentableContext<PictureInPictureLayerView>) -> PictureInPictureHostView {
        let container = PictureInPictureHostView(pipManager: pipManager)
        container.clipsToBounds = true
        container.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        let playerLayer = pipManager.playerLayer
        playerLayer.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        container.layer.addSublayer(playerLayer)
        return container
    }

    func updateUIView(_ uiView: PictureInPictureHostView,
                      context: UIViewRepresentableContext<PictureInPictureLayerView>) {}
}

class PictureInPictureHostView: UIView {
    private let pipManager: PictureInPictureManager

    init(pipManager: PictureInPictureManager) {
        self.pipManager = pipManager
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            Task { @MainActor in
                pipManager.layerDidMoveToWindow()
            }
        }
    }
}
