//
//  ProgressAlertManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/09.
//

import Foundation
import SwiftUI

@Observable
class ProgressAlertManager {
    var isDisplayed: Bool = false
    var title: LocalizedStringKey = ""
    var currentProgress: Int = 0
    var total: Int = 0
    var percentage: Int = 0

    func show() {
        isDisplayed = true
    }

    func hide() {
        isDisplayed = false
    }

    func prepare(_ title: LocalizedStringKey, total: Int = 0) {
        self.title = title
        self.currentProgress = 0
        self.total = total
        self.percentage = 0
    }

    func reset(using total: Int = 0) {
        self.title = ""
        self.currentProgress = 0
        self.total = total
        self.percentage = 0
    }

    func incrementProgress() {
        DispatchQueue.main.async { [self] in
            currentProgress += 1
            setProgress()
        }
    }

    func setProgress() {
        if total > 0 {
            percentage = Int((Float(currentProgress) / Float(total)) * 100.0)
        } else {
            percentage = 0
        }
    }
}
