import SwiftUI

struct ToastItem: Identifiable {
    let id = UUID()
    let message: String
    let systemImage: String
    let undo: (() async -> Void)?

    init(message: String, systemImage: String = "checkmark.circle.fill", undo: (() async -> Void)? = nil) {
        self.message = message
        self.systemImage = systemImage
        self.undo = undo
    }
}

@MainActor @Observable
final class ToastManager {

    static let shared = ToastManager()

    private(set) var current: ToastItem?
    var autoDismissInterval: Duration = .seconds(3)

    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ item: ToastItem) {
        withAnimation(.smooth(duration: 0.35)) {
            current = item
        }
        scheduleAutoDismiss()
    }

    func pauseAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    func resumeAutoDismiss() {
        guard current != nil else { return }
        scheduleAutoDismiss()
    }

    private func scheduleAutoDismiss() {
        dismissTask?.cancel()
        guard let current else { return }
        let id = current.id
        let interval = autoDismissInterval
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            self?.dismiss(matching: id)
        }
    }

    func dismiss(matching id: UUID) {
        if current?.id == id { dismiss() }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(.smooth(duration: 0.35)) {
            current = nil
        }
    }
}
