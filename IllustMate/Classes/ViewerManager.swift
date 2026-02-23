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

    var displayedPicID: String = ""
    var displayedPic: Pic?
    var displayedThumbnail: UIImage?
    var displayedImage: UIImage?
    var isFullImageLoaded: Bool = false

    @ObservationIgnored var imageCache: [String: UIImage] = [:]

    func setDisplay(_ pic: Pic, completion: @escaping @MainActor @Sendable () -> Void) {
        // Show thumbnail immediately to open viewer without delay
        let thumbnail: UIImage?
        if let thumbnailData = pic.thumbnailData {
            thumbnail = UIImage(data: thumbnailData)
        } else {
            thumbnail = nil
        }

        displayedThumbnail = thumbnail
        displayedPic = pic
        displayedPicID = pic.id
        isFullImageLoaded = false

        if let cachedImage = imageCache[pic.id] {
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
                if let data = await actor.imageData(forPicWithID: pic.id),
                   let image = await UIImage(data: data)?.byPreparingForDisplay() {
                    loadedImage = image
                }
                self.imageCache[pic.id] = loadedImage
                self.displayedImage = loadedImage
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.isFullImageLoaded = true
                }
            }
        }
    }
}
