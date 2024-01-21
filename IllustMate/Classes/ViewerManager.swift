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
            let intent = NSFileAccessIntent.readingIntent(with: URL(filePath: illustration.illustrationPath()))
            let coordinator = NSFileCoordinator()
            coordinator.coordinate(with: [intent], queue: queue) { error in
                if let error {
                    debugPrint(error.localizedDescription)
                } else {
                    var displayedImage: UIImage?
                    if let image = UIImage(contentsOfFile: illustration.illustrationPath()) {
                        displayedImage = image
                    }
                    self.imageCache[illustration.id] = displayedImage
                    // doWithAnimationAsynchronously {
                    self.displayedIllustrationID = illustration.id
                    self.displayedImage = displayedImage
                    self.displayedIllustration = illustration
                    // }
                }
            }
        }
    }

    func removeDisplay() {
        // doWithAnimationAsynchronously { [self] in
        displayedImage = nil
        displayedIllustration = nil
        displayedIllustrationID = ""
        // }
    }
}
