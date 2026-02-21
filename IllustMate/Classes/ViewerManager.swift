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
    @ObservationIgnored var displayedImage: UIImage?

    @ObservationIgnored var imageCache: [String: UIImage] = [:]

    func setDisplay(_ illustration: Illustration, completion: @escaping @MainActor @Sendable () -> Void) {
        if let image = imageCache[illustration.id] {
            displayedImage = image
            displayedIllustration = illustration
            displayedIllustrationID = illustration.id
            completion()
        } else {
            Task(priority: .userInitiated) {
                var loadedImage: UIImage?
                if let data = await actor.imageData(forIllustrationWithID: illustration.id),
                   let image = await UIImage(data: data)?.byPreparingForDisplay() {
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
