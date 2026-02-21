//
//  ViewerManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/13.
//

import Foundation
import SwiftUI

@MainActor @Observable
class ViewerManager {

    var displayedIllustrationID: String = ""
    @ObservationIgnored var displayedIllustration: Illustration?
    @ObservationIgnored var displayedThumbnail: UIImage?
    @ObservationIgnored var displayedImage: UIImage?
    var isFullImageLoaded: Bool = false

    @ObservationIgnored var imageCache: [String: UIImage] = [:]

    func setDisplay(_ illustration: Illustration, completion: @escaping @MainActor @Sendable () -> Void) {
        // Show thumbnail immediately to open viewer without delay
        let thumbnail: UIImage?
        if let thumbnailData = illustration.thumbnailData {
            thumbnail = UIImage(data: thumbnailData)
        } else {
            thumbnail = nil
        }

        displayedThumbnail = thumbnail
        displayedIllustration = illustration
        displayedIllustrationID = illustration.id
        isFullImageLoaded = false

        if let cachedImage = imageCache[illustration.id] {
            displayedImage = cachedImage
            isFullImageLoaded = true
        } else {
            displayedImage = nil
        }

        // Navigate immediately — viewer opens with thumbnail
        completion()

        // Load full image in background if not cached
        if !isFullImageLoaded {
            Task(priority: .userInitiated) {
                var loadedImage: UIImage?
                if let data = await actor.imageData(forIllustrationWithID: illustration.id),
                   let image = await UIImage(data: data)?.byPreparingForDisplay() {
                    loadedImage = image
                }
                self.imageCache[illustration.id] = loadedImage
                self.displayedImage = loadedImage
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.isFullImageLoaded = true
                }
            }
        }
    }

    func removeDisplay() {
        displayedImage = nil
        displayedThumbnail = nil
        displayedIllustration = nil
        displayedIllustrationID = ""
        isFullImageLoaded = false
    }
}
