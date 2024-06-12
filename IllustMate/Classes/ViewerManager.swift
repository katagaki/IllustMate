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
    @ObservationIgnored var displayedIllustration: Illustration?
    @ObservationIgnored var displayedImage: UIImage?

    @ObservationIgnored var imageCache: [String: UIImage] = [:]

    let queue: OperationQueue

    init() {
        queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
    }

    func setDisplay(_ illustration: Illustration, completion: @escaping () -> Void) {
        if let image = imageCache[illustration.id] {
            displayedImage = image
            displayedIllustration = illustration
            displayedIllustrationID = illustration.id
            completion()
        } else {
            let illustrationURL: URL = URL(filePath: illustration.illustrationPath())
            NSFileCoordinator().coordinate(readingItemAt: illustrationURL, error: .none) { url in
                Task(priority: .userInitiated) {
                    var loadedImage: UIImage?
                    if let image = await UIImage(contentsOfFile: url.path(percentEncoded: false))?
                        .byPreparingForDisplay() {
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
    }

    func removeDisplay() {
        displayedImage = nil
        displayedIllustration = nil
        displayedIllustrationID = ""
    }
}
