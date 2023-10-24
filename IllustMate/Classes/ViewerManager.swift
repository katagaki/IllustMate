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

    func setDisplay(_ illustration: Illustration) {
        if let image = imageCache[illustration.id] {
            if UserDefaults.standard.bool(forKey: "DebugAllAnimsOff") {
                displayedIllustrationID = illustration.id
                displayedImage = image
                displayedIllustration = illustration
            } else {
                doWithAnimationAsynchronously { [self] in
                    displayedIllustrationID = illustration.id
                    displayedImage = image
                    displayedIllustration = illustration
                }
            }
        } else {
            Task.detached(priority: .userInitiated) {
                do {
                    var displayedImage: UIImage?
                    if let image = UIImage(contentsOfFile: illustration.illustrationPath()) {
                        displayedImage = image
                    } else {
                        try FileManager.default.startDownloadingUbiquitousItem(
                            at: URL(filePath: illustration.illustrationPath()))
                        var isDownloaded: Bool = false
                        while !isDownloaded {
                            if FileManager.default.fileExists(atPath: illustration.illustrationPath()) {
                                isDownloaded = true
                            }
                        }
                        if let image = UIImage(contentsOfFile: illustration.illustrationPath()) {
                            displayedImage = image
                        }
                    }
                    await MainActor.run { [displayedImage] in
                        self.imageCache[illustration.id] = displayedImage
                        doWithAnimation {
                            self.displayedIllustrationID = illustration.id
                            self.displayedImage = displayedImage
                            self.displayedIllustration = illustration
                        }
                    }
                } catch {
                    debugPrint(error.localizedDescription)
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
