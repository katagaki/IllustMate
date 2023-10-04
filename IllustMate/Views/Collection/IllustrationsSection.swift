//
//  IllustrationsSection.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import SwiftUI

struct IllustrationsSection: View {

    @Environment(\.modelContext) var modelContext
    var illustrations: [Illustration]
    var currentAlbum: Album?
    var parentAlbum: Album?
    var selectableAlbums: [Album]
    var isRootAlbum: Bool = false
    @State var isSelectingIllustrations: Bool = false
    @State var selectedIllustrations: [Illustration] = []

    let illustrationsColumnConfiguration = [GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0.0) {
            HStack(alignment: .center, spacing: 16.0) {
                HStack(alignment: .center, spacing: 8.0) {
                    ListSectionHeader(text: "Albums.Illustrations")
                    if !illustrations.isEmpty {
                        Text("(\(illustrations.count))")
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelectingIllustrations {
                    Button {
                        selectedIllustrations.removeAll()
                        selectedIllustrations.append(contentsOf: illustrations)
                    } label: {
                        Text("Shared.SelectAll")
                    }
                }
                Button {
                    isSelectingIllustrations.toggle()
                    if !isSelectingIllustrations {
                        selectedIllustrations.removeAll()
                    }
                } label: {
                    Text("Shared.Select")
                        .padding([.leading, .trailing], 8.0)
                        .padding([.top, .bottom], 4.0)
                        .foregroundStyle(isSelectingIllustrations ? .white : .accent)
                        .background(isSelectingIllustrations ? .accent : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 99))
                }
            }
            .padding([.leading, .trailing], 20.0)
            .padding([.bottom], 6.0)
            Group {
                if !illustrations.isEmpty {
                    LazyVGrid(columns: illustrationsColumnConfiguration, spacing: 2.0) {
                        ForEach(illustrations, id: \.id) { illustration in
                            Group {
                                if isSelectingIllustrations {
                                    selectableIllustrationItem(illustration)
                                } else {
                                    nonSelectableIllustrationItem(illustration)
                                }
                            }
                            .draggable(IllustrationTransferable(illustration)) {
                                illustrationLabel(illustration)
                                    .frame(width: 100.0, height: 100.0)
                                    .clipShape(RoundedRectangle(cornerRadius: 8.0))
                            }
                        }
                    }
                } else {
                    Divider()
                        .padding([.leading], 20.0)
                    Text("Albums.NoIllustrations")
                        .foregroundStyle(.secondary)
                        .padding([.leading, .trailing, .top], 20.0)
                }
            }
        }
    }

    @ViewBuilder
    func selectableIllustrationItem(_ illustration: Illustration) -> some View {
        illustrationLabel(illustration)
            .overlay {
                if selectedIllustrations.contains(where: { $0.id == illustration.id }) {
                    Rectangle()
                        .foregroundStyle(.black)
                        .opacity(0.5)
                        .overlay {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32.0, height: 32.0)
                                .tint(.white)
                        }
                }
            }
            .onTapGesture {
                if selectedIllustrations.contains(where: { $0.id == illustration.id }) {
                    selectedIllustrations.removeAll(where: { $0.id == illustration.id })
                } else {
                    selectedIllustrations.append(illustration)
                }
            }
            .contextMenu {
                if selectedIllustrations.contains(where: { $0.id == illustration.id }) {
                    Menu {
                        moveToAlbumMenu(selectedIllustrations) {
                            selectedIllustrations.removeAll()
                        }
                    } label: {
                        Text("Shared.AddToAlbum")
                        Image(systemName: "rectangle.stack.badge.plus")
                    }
                    Button(role: .destructive) {
                        for illustration in selectedIllustrations {
                            illustration.prepareForDeletion()
                            modelContext.delete(illustration)
                        }
                    } label: {
                        Text("Shared.Delete")
                        Image(systemName: "trash")
                    }
                }
            }
    }

    @ViewBuilder
    func nonSelectableIllustrationItem(_ illustration: Illustration) -> some View {
        NavigationLink(value: ViewPath.illustrationViewer(illustration: illustration)) {
            illustrationLabel(illustration)
        }
        .contextMenu {
            Menu {
                moveToAlbumMenu([illustration]) { }
            } label: {
                Text("Shared.AddToAlbum")
                Image(systemName: "rectangle.stack.badge.plus")
            }
            Divider()
            if let currentAlbum = currentAlbum, let image = illustration.image() {
                Button {
                    currentAlbum.coverPhoto = Album.makeCover(image.pngData())
                } label: {
                    Text("Shared.SetAsCover")
                    Image(systemName: "photo.stack")
                }
                Divider()
            }
            Button {
                if let image = illustration.image() {
                    UIPasteboard.general.image = image
                }
            } label: {
                Text("Shared.Copy")
                Image(systemName: "doc.on.doc")
            }
            Button(role: .destructive) {
                illustration.prepareForDeletion()
                modelContext.delete(illustration)
            } label: {
                Text("Shared.Delete")
                Image(systemName: "trash")
            }
        } preview: {
            if let image = illustration.image() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    @ViewBuilder
    func moveToAlbumMenu(_ illustrations: [Illustration], postMoveAction: @escaping () -> Void) -> some View {
        if !isRootAlbum {
            if let parentAlbum = parentAlbum {
                Button {
                    parentAlbum.moveChildIllustrations(illustrations)
                    postMoveAction()
                } label: {
                    Text(parentAlbum.name)
                }
            } else {
                Button {
                    illustrations.forEach { illustration in
                        illustration.containingAlbums?.forEach({ album in
                            album.removeChildIllustration(illustration)
                        })
                    }
                    postMoveAction()
                } label: {
                    Text("Shared.MoveOutOfAlbum")
                }
            }
            Divider()
        }
        ForEach(selectableAlbums) { album in
            Button {
                album.moveChildIllustrations(illustrations)
                postMoveAction()
            } label: {
                Text(album.name)
            }
        }
    }

    @ViewBuilder
    func illustrationLabel(_ illustration: Illustration) -> some View {
        if let image = illustration.thumbnail() {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(1.0, contentMode: .fill)
                .transition(.opacity.animation(.snappy.speed(2)))
        } else {
            Rectangle()
                .foregroundStyle(.clear)
                .aspectRatio(1.0, contentMode: .fill)
                .overlay {
                    Image(systemName: "xmark.octagon.fill")
                        .symbolRenderingMode(.hierarchical)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28.0, height: 28.0)
                        .tint(.secondary)
                }
        }
    }
}
