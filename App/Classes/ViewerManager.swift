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

    var allPics: [Pic] = []
    var currentIndex: Int = 0

    var hasNext: Bool { currentIndex < allPics.count - 1 }
    var hasPrevious: Bool { currentIndex > 0 }

    @ObservationIgnored var imageCache: [String: UIImage] = [:]

    func setDisplay(_ pic: Pic, completion: @escaping @MainActor @Sendable () -> Void) {
        // Show thumbnail immediately to open viewer without delay
        let thumbnail: UIImage? = ThumbnailCache.shared.image(forKey: pic.id)
            ?? pic.thumbnailData.flatMap { UIImage(data: $0) }

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
            loadFullImage(for: pic.id)
        }
    }

    func setDisplay(_ pic: Pic, in pics: [Pic], completion: @escaping @MainActor @Sendable () -> Void) {
        allPics = pics
        currentIndex = pics.firstIndex(where: { $0.id == pic.id }) ?? 0
        setDisplay(pic, completion: completion)
    }

    func navigateTo(index: Int) {
        guard index >= 0, index < allPics.count else { return }
        currentIndex = index
        let pic = allPics[index]

        let thumbnail: UIImage? = ThumbnailCache.shared.image(forKey: pic.id)
            ?? pic.thumbnailData.flatMap { UIImage(data: $0) }

        displayedThumbnail = thumbnail
        displayedPic = pic
        displayedPicID = pic.id
        isFullImageLoaded = false

        if let cachedImage = imageCache[pic.id] {
            displayedImage = cachedImage
            isFullImageLoaded = true
        } else {
            displayedImage = nil
            loadFullImage(for: pic.id)
        }
    }

    func navigateToNext() {
        if hasNext {
            navigateTo(index: currentIndex + 1)
        }
    }

    func navigateToPrevious() {
        if hasPrevious {
            navigateTo(index: currentIndex - 1)
        }
    }

    private func loadFullImage(for picID: String) {
        Task(priority: .userInitiated) {
            var loadedImage: UIImage?
            if let data = await DataActor.shared.imageData(forPicWithID: picID),
               let image = await UIImage(data: data)?.byPreparingForDisplay() {
                loadedImage = image
            }
            self.imageCache[picID] = loadedImage
            if self.displayedPicID == picID {
                self.displayedImage = loadedImage
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.isFullImageLoaded = true
                }
                // Prefetch adjacent images after current one loads
                prefetchAdjacentImages()
            }
        }
    }

    private func prefetchAdjacentImages() {
        let indicesToPrefetch = [currentIndex - 1, currentIndex + 1]
        for index in indicesToPrefetch {
            guard index >= 0, index < allPics.count else { continue }
            let pic = allPics[index]
            guard imageCache[pic.id] == nil else { continue }
            Task.detached(priority: .utility) {
                if let data = await DataActor.shared.imageData(forPicWithID: pic.id),
                   let image = await UIImage(data: data)?.byPreparingForDisplay() {
                    await MainActor.run {
                        self.imageCache[pic.id] = image
                    }
                }
            }
        }
    }
}
