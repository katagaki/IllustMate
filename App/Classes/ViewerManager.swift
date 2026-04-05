//
//  ViewerManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/13.
//

import AVFoundation
import Foundation
import StoreKit
import SwiftUI

@MainActor @Observable
class ViewerManager {

    static let picOpenCountKey = "PicOpenCount"

    var displayedPicID: String = ""
    var displayedPic: Pic?
    var displayedThumbnail: UIImage?
    var displayedImage: UIImage?
    var isFullImageLoaded: Bool = false
    var displayedVideoURL: URL?
    var videoPlayer: AVPlayer?

    var allPics: [Pic] = []
    var currentIndex: Int = 0

    var hasNext: Bool { currentIndex < allPics.count - 1 }
    var hasPrevious: Bool { currentIndex > 0 }

    @ObservationIgnored var imageCache: [String: UIImage] = [:]
    @ObservationIgnored private var prefetchTasks: [String: Task<Void, Never>] = [:]

    /// Maximum number of full-resolution images to keep cached around the current index.
    private let cacheWindow = 5

    func clearDisplay() {
        displayedPicID = ""
        displayedPic = nil
        displayedThumbnail = nil
        displayedImage = nil
        isFullImageLoaded = false
        videoPlayer?.pause()
        videoPlayer = nil
        displayedVideoURL = nil
        allPics = []
        currentIndex = 0
        for task in prefetchTasks.values {
            task.cancel()
        }
        prefetchTasks.removeAll()
        imageCache.removeAll()
    }

    func removePics(withIDs deletedIDs: Set<String>) {
        // If the currently displayed pic was deleted, clear the display
        if deletedIDs.contains(displayedPicID) {
            clearDisplay()
            return
        }
        // Otherwise, remove deleted pics from the navigation list
        allPics.removeAll { deletedIDs.contains($0.id) }
        // Recompute currentIndex for the displayed pic
        if let displayedPic,
           let newIndex = allPics.firstIndex(where: { $0.id == displayedPic.id }) {
            currentIndex = newIndex
        }
        // Evict deleted entries from caches
        for id in deletedIDs {
            imageCache.removeValue(forKey: id)
            prefetchTasks.removeValue(forKey: id)?.cancel()
        }
    }

    func setDisplay(_ pic: Pic, completion: @escaping @MainActor @Sendable () -> Void) {
        // Track pic opens for review prompt
        Self.incrementPicOpenCount()

        // Show thumbnail immediately to open viewer without delay
        let thumbnail: UIImage? = ThumbnailCache.shared.image(forKey: pic.id)
            ?? pic.thumbnailData.flatMap { UIImage(data: $0) }

        displayedThumbnail = thumbnail
        displayedPic = pic
        displayedPicID = pic.id
        isFullImageLoaded = false

        // Clean up previous video state
        videoPlayer?.pause()
        videoPlayer = nil
        displayedVideoURL = nil

        if pic.isVideo {
            // Load video URL
            Task {
                if let url = await DataActor.shared.videoURL(forPicWithID: pic.id) {
                    self.displayedVideoURL = url
                    self.videoPlayer = AVPlayer(url: url)
                }
            }
            isFullImageLoaded = true
        } else if let cachedImage = imageCache[pic.id] {
            displayedImage = cachedImage
            isFullImageLoaded = true
        } else {
            displayedImage = nil
        }

        // Navigate immediately — viewer opens with thumbnail
        completion()

        // Load full image in background if not cached (images only)
        if !pic.isVideo && !isFullImageLoaded {
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

        // Clean up previous video state
        videoPlayer?.pause()
        videoPlayer = nil
        displayedVideoURL = nil

        if pic.isVideo {
            Task {
                if let url = await DataActor.shared.videoURL(forPicWithID: pic.id) {
                    self.displayedVideoURL = url
                    self.videoPlayer = AVPlayer(url: url)
                }
            }
            isFullImageLoaded = true
        } else if let cachedImage = imageCache[pic.id] {
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
                self.isFullImageLoaded = true
                // Prefetch adjacent images after current one loads
                prefetchAdjacentImages()
                // Evict images far from the current position
                evictDistantCacheEntries()
            }
        }
    }

    private func prefetchAdjacentImages() {
        // Cancel any prefetch tasks for pics that are no longer adjacent
        cancelStalePrefetchTasks()

        let indicesToPrefetch = [currentIndex - 1, currentIndex + 1]
        for index in indicesToPrefetch {
            guard index >= 0, index < allPics.count else { continue }
            let pic = allPics[index]
            guard imageCache[pic.id] == nil, prefetchTasks[pic.id] == nil else { continue }
            let picID = pic.id
            let task = Task.detached(priority: .utility) {
                if let data = await DataActor.shared.imageData(forPicWithID: picID),
                   let image = await UIImage(data: data)?.byPreparingForDisplay() {
                    _ = await MainActor.run {
                        self.imageCache[picID] = image
                        self.prefetchTasks.removeValue(forKey: picID)
                    }
                } else {
                    _ = await MainActor.run {
                        self.prefetchTasks.removeValue(forKey: picID)
                    }
                }
            }
            prefetchTasks[picID] = task
        }
    }

    private func cancelStalePrefetchTasks() {
        let adjacentIDs: Set<String> = {
            var ids = Set<String>()
            for offset in -1...1 {
                let index = currentIndex + offset
                if index >= 0, index < allPics.count {
                    ids.insert(allPics[index].id)
                }
            }
            return ids
        }()

        for (picID, task) in prefetchTasks where !adjacentIDs.contains(picID) {
            task.cancel()
            prefetchTasks.removeValue(forKey: picID)
        }
    }

    private func evictDistantCacheEntries() {
        guard !allPics.isEmpty else { return }
        let keepRange = max(0, currentIndex - cacheWindow)...min(allPics.count - 1, currentIndex + cacheWindow)
        let keepIDs = Set(allPics[keepRange].map(\.id))

        for key in imageCache.keys where !keepIDs.contains(key) {
            imageCache.removeValue(forKey: key)
        }
    }

    static func incrementPicOpenCount() {
        let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")
        let count = (defaults?.integer(forKey: picOpenCountKey) ?? 0) + 1
        defaults?.set(count, forKey: picOpenCountKey)
    }

    static var picOpenCount: Int {
        UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")?.integer(forKey: picOpenCountKey) ?? 0
    }
}
