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

    @Binding var illustrations: [Illustration]
    @Binding var isSelecting: Bool
    @State var enableSelection: Bool = true
    var isViewing: (Illustration) -> Bool
    var isSelected: (Illustration) -> Bool
    var onSelect: (Illustration) -> Void
    var selectedCount: () -> Int
    var onDelete: (Illustration) -> Void
    @ViewBuilder var moveMenu: (Illustration) -> Content

    let phoneColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 2.0)]
#if targetEnvironment(macCatalyst)
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 4.0)]
#else
    let padOrMacColumnConfiguration = [GridItem(.adaptive(minimum: 160.0), spacing: 4.0)]
#endif

    var body: some View {
        LazyVGrid(
            columns: UIDevice.current.userInterfaceIdiom == .phone ?
                     phoneColumnConfiguration : padOrMacColumnConfiguration,
            spacing: UIDevice.current.userInterfaceIdiom == .phone ? 2.0 : 4.0) {
            ForEach(illustrations, id: \.id) { illustration in
                Button {
                    onSelect(illustration)
                } label: {
                    IllustrationLabel(namespace: namespace, illustration: illustration)
                        .opacity(isViewing(illustration) ? 0.0 : 1.0)
                        .overlay {
                            if isSelected(illustration) {
                                SelectionOverlay()
                            }
                        }
                }
                .contextMenu {
                    if isSelecting {
                        if isSelected(illustration) {
                            Text("Shared.Selected.\(selectedCount())")
                            Divider()
                            moveMenu(illustration)
                            Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                                onDelete(illustration)
                            }
                        }
                    } else {
                        if enableSelection {
                            Button("Shared.Select", systemImage: "checkmark.circle") {
                                withAnimation(.snappy.speed(2)) {
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
                        if let containingAlbum = illustration.containingAlbum {
                            Button("Shared.SetAsCover", systemImage: "photo") {
                                let image = UIImage(contentsOfFile: illustration.illustrationPath())
                                if let data = image?.jpegData(compressionQuality: 1.0) {
                                    containingAlbum.coverPhoto = Album.makeCover(data)
                                }
                            }
                        }
                        Divider()
                        moveMenu(illustration)
                        Divider()
                        Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                            onDelete(illustration)
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
#endif
            }
        }
        .background(colorScheme == .light ?
                    Color.init(uiColor: .secondarySystemGroupedBackground) :
                        Color.init(uiColor: .systemBackground))
    }
}
