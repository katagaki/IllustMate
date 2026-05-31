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
