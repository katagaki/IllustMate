import SwiftUI

struct ToastOverlayView: View {

    var priority: Int = 0
    var topPadding: CGFloat = 16.0
    var onUndoComplete: () -> Void = {}

    @State private var manager = ToastManager.shared
    @State private var presenterID = UUID()
    @State private var dragOffset: CGFloat = 0
    @State private var isShowingUndoConfirmation = false

    var body: some View {
        // A ZStack, not a Group: Group forwards onAppear to its children, so an empty
        // toast slot would never register itself as a presenter.
        ZStack(alignment: .top) {
            if manager.isActivePresenter(presenterID), let item = manager.current {
                toast(item)
                    .id(item.id)
                    .padding(.top, topPadding)
                    .padding(.horizontal, 16.0)
                    .transition(.move(edge: .top).combined(with: .blurReplace))
            }
        }
        .animation(.smooth(duration: 0.35), value: manager.current?.id)
        .onAppear {
            manager.registerPresenter(id: presenterID, priority: priority)
        }
        .onDisappear {
            manager.unregisterPresenter(id: presenterID)
        }
    }

    private func toast(_ item: ToastItem) -> some View {
        HStack(spacing: 8.0) {
            Image(systemName: item.systemImage)
                .foregroundStyle(.primary)
            Text(item.message)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            if item.undo != nil {
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16.0)
        .padding(.vertical, 12.0)
        .glassEffect(.regular.tint(item.tint?.opacity(0.2)).interactive(), in: .capsule)
        .contentShape(.capsule)
        .offset(y: dragOffset)
        .gesture(dragGesture)
        .onTapGesture {
            if item.undo != nil {
                manager.pauseAutoDismiss()
                isShowingUndoConfirmation = true
            }
        }
        .alert(
            Text("Toast.UndoMove.Question", tableName: "Photos"),
            isPresented: $isShowingUndoConfirmation
        ) {
            Button("Shared.Yes") {
                Task {
                    await item.undo?()
                    onUndoComplete()
                    manager.dismiss()
                }
            }
            Button("Shared.No", role: .cancel) {
                manager.resumeAutoDismiss()
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = min(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height < -20.0 {
                    manager.dismiss()
                }
                dragOffset = 0
            }
    }
}
