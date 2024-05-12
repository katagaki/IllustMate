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
    var displayedIllustration: Illustration?
    var displayedImage: UIImage?

    @ObservationIgnored var imageCache: [String: UIImage] = [:]

    let queue: OperationQueue

    init() {
        queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
    }

    func setDisplay(_ illustration: Illustration) {
        if let image = imageCache[illustration.id] {
            doWithAnimationAsynchronously { [self] in
                displayedIllustrationID = illustration.id
                displayedImage = image
                displayedIllustration = illustration
            }
        } else {
            let illustrationURL: URL = URL(filePath: illustration.illustrationPath())
            NSFileCoordinator().coordinate(readingItemAt: illustrationURL, error: .none) { url in
                Task {
                    var loadedImage: UIImage?
                    if let image = await UIImage(contentsOfFile: url.path(percentEncoded: false))?
                        .byPreparingForDisplay() {
                        loadedImage = image
                    }
                    doWithAnimationAsynchronously { [self] in
                        displayedIllustrationID = illustration.id
                        displayedImage = loadedImage
                        displayedIllustration = illustration
                    }
                    self.imageCache[illustration.id] = loadedImage
                }
            }
        }
    }

    func removeDisplay() {
        doWithAnimationAsynchronously { [self] in
            displayedImage = nil
            displayedIllustration = nil
            displayedIllustrationID = ""
        }
    }
}
