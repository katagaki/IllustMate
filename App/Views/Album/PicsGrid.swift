import SwiftUI

struct PicsGrid<Content: View>: View {

    @Environment(\.colorScheme) var colorScheme

    var namespace: Namespace.ID

    var pics: [Pic]
    var placeholderCount: Int = 0
    @Binding var isSelecting: Bool
    @State var enableSelection: Bool = true
    var columnCount: Int = 4
    var isSelected: ((Pic) -> Bool)?
    var onSelect: (Pic) -> Void
    var selectedCount: () -> Int
    var onRename: ((Pic) -> Void)?
    var onDelete: ((Pic) -> Void)?
    @ViewBuilder var moveMenu: (Pic) -> Content

    private static var selectionSpace: String { "PicsGridSelectionSpace" }

    @State private var gridWidth: CGFloat = 0.0
    @State private var anchorIndex: Int?
    @State private var paintSelected: Bool = false
    @State private var paintedRange: ClosedRange<Int>?
    @State private var originalSelected: [Int: Bool] = [:]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2.0), count: columnCount),
                  spacing: 2.0) {
            ForEach(pics) { pic in
                PicLabel(pic: pic)
                    .overlay {
                        if isSelecting {
                            if let isSelected {
                                ZStack(alignment: .bottomTrailing) {
                                    SelectionOverlay(isSelected(pic))
                                    Color.clear
                                }
                                .transition(.opacity.animation(.smooth.speed(2.0)))
                            }
                        }
                    }
                    .contentShape(.rect)
                    .onTapGesture {
                        onSelect(pic)
                    }
                    .modifier(PicExportDraggableModifier(pic: pic, isSelecting: isSelecting))
                    .matchedTransitionSource(id: pic.id, in: namespace)
                    .contextMenu {
                    if !isSelecting {
                        if enableSelection {
                            Button("Shared.Select", systemImage: "checkmark.circle") {
                                doWithAnimation {
                                    isSelecting = true
                                    onSelect(pic)
                                }
                            }
                            Divider()
                        }
                        Button("Shared.Copy", systemImage: "doc.on.doc") {
                            Task {
                                if let data = await DataActor.shared.imageData(forPicWithID: pic.id),
                                   let image = UIImage(data: data) {
                                    UIPasteboard.general.image = image
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                }
                            }
                        }
                        ShareLink(item: PicShareable(picID: pic.id),
                                  preview: SharePreview(pic.name,
                                                        image: PicShareable(picID: pic.id))) {
                            Label("Shared.Share", systemImage: "square.and.arrow.up")
                        }
                        if let onRename {
                            Divider()
                            Button("Shared.Rename", systemImage: "pencil") {
                                onRename(pic)
                            }
                        }
                        Divider()
                        if let albumID = pic.containingAlbumID {
                            Button("Shared.SetAsCover", systemImage: "photo") {
                                Task {
                                    await DataActor.shared.setAsAlbumCover(for: pic.id)
                                    AlbumCoverCache.shared.removeImages(forAlbumID: albumID)
                                }
                            }
                        }
                        Divider()
                        moveMenu(pic)
                        if let onDelete {
                            Divider()
                            Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                                onDelete(pic)
                            }
                        }
                    }
                } preview: {
                    PicPreview(picID: pic.id)
                }
#if targetEnvironment(macCatalyst)
                .hoverEffect(.highlight)
#endif
            }
            if placeholderCount > 0 {
                let visiblePlaceholders = min(placeholderCount, columnCount * 10)
                ForEach(0..<visiblePlaceholders, id: \.self) { _ in
                    Rectangle()
                        .fill(.primary.opacity(0.05))
                        .aspectRatio(1.0, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 4.0))
                }
            }
        }
        .coordinateSpace(.named(Self.selectionSpace))
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            gridWidth = width
        }
        .gesture(SelectionPanGesture(isEnabled: isSelecting,
                                     coordinateSpace: Self.selectionSpace,
                                     onChange: { updateSelection(at: $0) },
                                     onEnd: { resetSelectionDrag() }))
        .animation(.smooth.speed(2.0), value: columnCount)
    }

    private func resetSelectionDrag() {
        anchorIndex = nil
        paintedRange = nil
        originalSelected.removeAll()
    }

    private func picIndex(at location: CGPoint) -> Int? {
        guard gridWidth > 0.0, columnCount > 0,
              location.x >= 0.0, location.y >= 0.0 else {
            return nil
        }
        let spacing = 2.0
        let itemWidth = (gridWidth - spacing * Double(columnCount - 1)) / Double(columnCount)
        guard itemWidth > 0.0 else { return nil }
        let pitch = itemWidth + spacing
        let column = Int(location.x / pitch)
        let row = Int(location.y / pitch)
        guard column >= 0, column < columnCount else { return nil }
        let index = row * columnCount + column
        guard index >= 0, index < pics.count else { return nil }
        return index
    }

    private func setSelected(_ index: Int, _ selected: Bool) {
        let pic = pics[index]
        if (isSelected?(pic) ?? false) != selected {
            onSelect(pic)
        }
    }

    private func updateSelection(at location: CGPoint) {
        guard let current = picIndex(at: location) else { return }
        guard let anchor = anchorIndex else {
            let original = isSelected?(pics[current]) ?? false
            originalSelected[current] = original
            paintSelected = !original
            anchorIndex = current
            paintedRange = current...current
            setSelected(current, paintSelected)
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }
        let newRange = min(anchor, current)...max(anchor, current)
        if newRange == paintedRange { return }
        if let old = paintedRange {
            for index in old where !newRange.contains(index) {
                setSelected(index, originalSelected[index] ?? false)
            }
        }
        for index in newRange where !(paintedRange?.contains(index) ?? false) {
            if originalSelected[index] == nil {
                originalSelected[index] = isSelected?(pics[index]) ?? false
            }
            setSelected(index, paintSelected)
        }
        paintedRange = newRange
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

struct PicShareable: Transferable {
    let picID: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { shareable in
            if let data = await DataActor.shared.imageData(forPicWithID: shareable.picID),
               let image = UIImage(data: data),
               let pngData = image.pngData() {
                return pngData
            }
            return Data()
        }
    }
}

struct PicPreview: View {
    let picID: String

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Rectangle()
                    .fill(.primary.opacity(0.05))
                    .frame(width: 200, height: 200)
            }
        }
        .task {
            if let thumbData = await DataActor.shared.thumbnailData(forPicWithID: picID),
               let uiImage = UIImage(data: thumbData) {
                image = uiImage
            }
        }
    }
}
