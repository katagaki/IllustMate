import SwiftUI

struct ToastItem: Identifiable {
    let id = UUID()
    let message: String
    let systemImage: String
    let tint: Color?
    let undo: (() async -> Void)?

    init(message: String, systemImage: String = "checkmark.circle.fill",
         tint: Color? = .green, undo: (() async -> Void)? = nil) {
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
        self.undo = undo
    }
}

@MainActor @Observable
final class ToastManager {

    static let shared = ToastManager()

    private(set) var current: ToastItem?
    var autoDismissInterval: Duration = .seconds(3)

    private var dismissTask: Task<Void, Never>?
    private var presenters: [(id: UUID, priority: Int)] = []

    private init() {}

    func registerPresenter(id: UUID, priority: Int) {
        presenters.removeAll { $0.id == id }
        presenters.append((id: id, priority: priority))
    }

    func unregisterPresenter(id: UUID) {
        presenters.removeAll { $0.id == id }
    }

    func isActivePresenter(_ id: UUID) -> Bool {
        guard let topPriority = presenters.map(\.priority).max() else { return false }
        return presenters.last { $0.priority == topPriority }?.id == id
    }

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
