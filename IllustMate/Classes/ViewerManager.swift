//
//  ViewerManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/13.
//

import Foundation
import SwiftUI

@Observable
class ViewerManager {

    var displayedIllustrationID: String = ""
    @ObservationIgnored var displayedIllustration: PhotoIllustration?
    @ObservationIgnored var displayedImage: UIImage?

    @ObservationIgnored var imageCache: [String: UIImage] = [:]

    let queue: OperationQueue

    init() {
        queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
    }

    func setDisplay(_ illustration: PhotoIllustration, completion: @escaping () -> Void) {
        if let image = imageCache[illustration.id] {
            displayedImage = image
            displayedIllustration = illustration
            displayedIllustrationID = illustration.id
            completion()
        } else {
            Task(priority: .userInitiated) {
                var loadedImage: UIImage?
                if let image = await illustration.loadImage() {
                    loadedImage = image
                }
                imageCache[illustration.id] = loadedImage
                displayedImage = loadedImage
                displayedIllustration = illustration
                displayedIllustrationID = illustration.id
                completion()
            }
        }
    }

    func removeDisplay() {
        displayedImage = nil
        displayedIllustration = nil
        displayedIllustrationID = ""
    }
}
