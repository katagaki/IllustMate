//
//  IllustrationsGrid.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/08.
//

import SwiftUI

struct IllustrationsGrid<Content: View>: View {

    @Environment(\.colorScheme) var colorScheme

    var namespace: Namespace.ID

    var illustrations: [Illustration]
    @Binding var isSelecting: Bool
    @State var enableSelection: Bool = true
    var isSelected: ((Illustration) -> Bool)?
    var onSelect: (Illustration) -> Void
    var selectedCount: () -> Int
    var onDelete: ((Illustration) -> Void)?
    @ViewBuilder var moveMenu: (Illustration) -> Content

    let phoneColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 2.0)]
#if targetEnvironment(macCatalyst)
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 2.0)]
#else
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 120.0), spacing: 2.0)]
#endif

    var body: some View {
        LazyVGrid(columns: UIDevice.current.userInterfaceIdiom == .phone ?
                  phoneColumnConfiguration : padOrMacColumnConfiguration,
                  spacing: 2.0) {
            ForEach(illustrations) { illustration in
                Button {
                    onSelect(illustration)
                } label: {
                    IllustrationLabel(namespace: namespace, illustration: illustration)
                    .overlay {
                        if isSelecting {
                            if let isSelected {
                                ZStack(alignment: .bottomTrailing) {
                                    SelectionOverlay(isSelected(illustration))
                                    Color.clear
                                }
                            }
                        }
                    }
                    .draggable(IllustrationTransferable(id: illustration.id)) {
                        if let image = illustration.thumbnail() {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100.0, height: 100.0)
                        }
                    }
                }
                .automaticMatchedTransitionSource(id: illustration.id, in: namespace)
                .contextMenu {
                    if !isSelecting {
                        if enableSelection {
                            Button("Shared.Select", systemImage: "checkmark.circle") {
                                doWithAnimation {
                                    isSelecting = true
                                    onSelect(illustration)
                                }
                            }
                            Divider()
                        }
                        Button("Shared.Copy", systemImage: "doc.on.doc") {
                            Task {
                                if let data = await actor.imageData(forIllustrationWithID: illustration.id),
                                   let image = UIImage(data: data) {
                                    UIPasteboard.general.image = image
                                }
                            }
                        }
                        ShareLink(item: IllustrationShareable(illustrationID: illustration.id),
                                  preview: SharePreview(illustration.name)) {
                            Label("Shared.Share", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        if illustration.containingAlbumID != nil {
                            Button("Shared.SetAsCover", systemImage: "photo") {
                                Task {
                                    await actor.setAsAlbumCover(for: illustration.id)
                                }
                            }
                        }
                        Divider()
                        moveMenu(illustration)
                        if let onDelete {
                            Divider()
                            Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                                onDelete(illustration)
                            }
                        }
                    }
                } preview: {
                    if let thumbnailData = illustration.thumbnailData,
                       let image = UIImage(data: thumbnailData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                }
#if targetEnvironment(macCatalyst)
                .buttonStyle(.borderless)
#else
                .buttonStyle(.plain)
#endif
            }
        }
    }
}

struct IllustrationShareable: Transferable {
    let illustrationID: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .image) { shareable in
            await actor.imageData(forIllustrationWithID: shareable.illustrationID) ?? Data()
        }
    }
}
