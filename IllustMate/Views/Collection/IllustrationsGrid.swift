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

    @State var thumbnails: [String: Data] = [:]

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
            ForEach(illustrations, id: \.persistentModelID) { illustration in
                Button {
                    onSelect(illustration)
                } label: {
                    Group {
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            IllustrationLabel(namespace: namespace, illustration: illustration)
                        } else {
                            IllustrationLabel(namespace: namespace, illustration: illustration)
                        }
                    }
                    .overlay {
                        if let isSelected, isSelected(illustration) {
                            SelectionOverlay()
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
                            if let image = UIImage(contentsOfFile: illustration.illustrationPath()) {
                                UIPasteboard.general.image = image
                            }
                        }
                        if let image = UIImage(contentsOfFile: illustration.illustrationPath()) {
                            ShareLink(item: Image(uiImage: image),
                                      preview: SharePreview(illustration.name, image: Image(uiImage: image))) {
                                Label("Shared.Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        Divider()
                        if illustration.containingAlbum != nil {
                            Button("Shared.SetAsCover", systemImage: "photo") {
                                Task {
                                    await actor.setAsAlbumCover(for: illustration.persistentModelID)
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
                    if let image = UIImage(contentsOfFile: illustration.illustrationPath()) {
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
        .background(colorScheme == .light ?
                    Color.init(uiColor: .secondarySystemGroupedBackground) :
                        Color.init(uiColor: .systemBackground))
    }
}
