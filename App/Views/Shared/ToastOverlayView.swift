import SwiftUI

struct ToastOverlayView: View {

    var onUndoComplete: () -> Void

    @State private var manager = ToastManager.shared
    @State private var dragOffset: CGFloat = 0
    @State private var isShowingUndoConfirmation = false

    var body: some View {
        Group {
            if let item = manager.current {
                toast(item)
                    .id(item.id)
                    .padding(.top, 50.0)
                    .padding(.horizontal, 16.0)
                    .transition(.move(edge: .top).combined(with: .blurReplace))
            }
        }
        .animation(.smooth(duration: 0.35), value: manager.current?.id)
    }

    private func toast(_ item: ToastItem) -> some View {
        HStack(spacing: 8.0) {
            Image(systemName: item.systemImage)
                .foregroundStyle(.green)
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
        .glassEffect(.regular.interactive(), in: .capsule)
        .offset(y: dragOffset)
        .gesture(dragGesture)
        .onTapGesture {
            if item.undo != nil {
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
            Button("Shared.No", role: .cancel) {}
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
