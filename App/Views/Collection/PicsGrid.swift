//
//  PicsGrid.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftUI

struct PicsGrid<Content: View>: View {

    @Environment(\.colorScheme) var colorScheme

    var namespace: Namespace.ID

    var pics: [Pic]
    var placeholderCount: Int = 0
    @Binding var isSelecting: Bool
    @State var enableSelection: Bool = true
    var isSelected: ((Pic) -> Bool)?
    var onSelect: (Pic) -> Void
    var selectedCount: () -> Int
    var onRename: ((Pic) -> Void)?
    var onDelete: ((Pic) -> Void)?
    @ViewBuilder var moveMenu: (Pic) -> Content

    @AppStorage(wrappedValue: 4, "PicColumnCount",
                store: UserDefaults(suiteName: "group.com.tsubuzaki.IllustMate")) var columnCount: Int

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
                    .draggable(PicTransferable(id: pic.id))
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
        .animation(.smooth.speed(2.0), value: columnCount)
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
