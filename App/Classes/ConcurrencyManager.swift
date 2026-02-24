//
//  ConcurrencyManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/12.
//

import Foundation

@Observable
class ConcurrencyManager {

    let queue: OperationQueue

    init() {
        queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 8
    }
}
