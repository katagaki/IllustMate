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

    var displayedIllustration: Illustration?
    var displayedImage: UIImage?

    var imageCache: [String: UIImage] = [:]

    func setDisplay(_ illustration: Illustration) {
        displayedIllustration = illustration
        do {
            if let image = imageCache[illustration.id] {
                displayedImage = image
            } else {
                if let data = try? Data(contentsOf: URL(filePath: illustration.illustrationPath())),
                   let image = UIImage(data: data) {
                    displayedImage = image
                    imageCache[illustration.id] = image
                } else {
                    try FileManager.default.startDownloadingUbiquitousItem(
                        at: URL(filePath: illustration.illustrationPath()))
                    var isDownloaded: Bool = false
                    while !isDownloaded {
                        if FileManager.default.fileExists(atPath: illustration.illustrationPath()) {
                            isDownloaded = true
                        }
                    }
                    let data = try? Data(contentsOf: URL(filePath: illustration.illustrationPath()))
                    if let data, let image = UIImage(data: data) {
                        displayedImage = image
                        imageCache[illustration.id] = image
                    }
                }
            }
        } catch {
            debugPrint(error.localizedDescription)
        }
    }

    func removeDisplay() {
        displayedImage = nil
        displayedIllustration = nil
    }
}
