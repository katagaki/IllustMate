//
//  IllustrationsSection.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import SwiftData
import SwiftUI

struct IllustrationsSection: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @Query(sort: \Illustration.dateAdded,
           order: .reverse,
           animation: .snappy.speed(2)) var illustrations: [Illustration]

    var currentAlbum: Album?
    var selectableAlbums: [Album]
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
                    if !illustrations.filter({ $0.isInAlbum(currentAlbum) }).isEmpty {
                        Text("(\(illustrations.filter({ $0.isInAlbum(currentAlbum) }).count))")
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelectingIllustrations {
                    Button {
                        selectedIllustrations.removeAll()
                        selectedIllustrations.append(contentsOf: illustrations.filter({ $0.isInAlbum(currentAlbum) }))
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
                        ForEach(illustrations.filter({ $0.isInAlbum(currentAlbum) }), id: \.id) { illustration in
                            illustrationItem(illustration)
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
    func illustrationLabel(_ illustration: Illustration) -> some View {
        if let thumbnailImage = illustration.thumbnail() {
            Image(uiImage: thumbnailImage)
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

    @ViewBuilder
    func selectionOverlay() -> some View {
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

    @ViewBuilder
    func illustrationItem(_ illustration: Illustration) -> some View {
        illustrationLabel(illustration)
            .overlay {
                if selectedIllustrations.contains(where: { $0.id == illustration.id }) {
                    selectionOverlay()
                }
            }
            .onTapGesture {
                if isSelectingIllustrations {
                    if selectedIllustrations.contains(where: { $0.id == illustration.id }) {
                        selectedIllustrations.removeAll(where: { $0.id == illustration.id })
                    } else {
                        selectedIllustrations.append(illustration)
                    }
                } else {
                    navigationManager.push(ViewPath.illustrationViewer(illustration: illustration), for: .collection)
                }
            }
            .contextMenu {
                contextMenu(illustration)
            } preview: {
                if let image = illustration.image() {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
            .draggable(IllustrationTransferable(illustration)) {
                illustrationLabel(illustration)
                    .frame(width: 100.0, height: 100.0)
                    .clipShape(RoundedRectangle(cornerRadius: 8.0))
            }
    }

    @ViewBuilder
    func contextMenu(_ illustration: Illustration) -> some View {
        if isSelectingIllustrations {
            if selectedIllustrations.contains(where: { $0.id == illustration.id }) {
                Menu {
                    moveToAlbumMenu(selectedIllustrations) {
                        selectedIllustrations.removeAll()
                    }
                } label: {
                    Label("Shared.AddToAlbum", systemImage: "rectangle.stack.badge.plus")
                }
                Button(role: .destructive) {
                    for illustration in selectedIllustrations {
                        illustration.prepareForDeletion()
                        modelContext.delete(illustration)
                    }
                } label: {
                    Label("Shared.Delete", systemImage: "trash")
                }
            }
        } else {
            Menu {
                moveToAlbumMenu([illustration]) { }
            } label: {
                Label("Shared.AddToAlbum", systemImage: "rectangle.stack.badge.plus")
            }
            Divider()
            if let currentAlbum = currentAlbum, let image = illustration.image() {
                Button {
                    currentAlbum.coverPhoto = Album.makeCover(image.pngData())
                } label: {
                    Label("Shared.SetAsCover", systemImage: "photo.stack")
                }
                Divider()
            }
            Button {
                if let image = illustration.image() {
                    UIPasteboard.general.image = image
                }
            } label: {
                Label("Shared.Copy", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) {
                illustration.prepareForDeletion()
                modelContext.delete(illustration)
            } label: {
                Label("Shared.Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    func moveToAlbumMenu(_ illustrations: [Illustration], postMoveAction: @escaping () -> Void) -> some View {
        if let currentAlbum = currentAlbum {
            if let parentAlbum = currentAlbum.parentAlbum {
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
}
