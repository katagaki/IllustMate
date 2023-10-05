//
//  AlbumView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftUI
import SwiftData

// swiftlint:disable type_body_length function_body_length file_length
struct AlbumView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @State var albums: [Album] = []
    @State var illustrations: [Illustration] = []
    @State var currentAlbum: Album?

    @State var isAddingAlbum: Bool = false
    @State var albumToRename: Album?

    @State var isSelectingIllustrations: Bool = false
    @State var selectedIllustrations: [Illustration] = []

    let albumColumnConfiguration = [GridItem(.flexible(), spacing: 20.0),
                                    GridItem(.flexible(), spacing: 20.0)]
    let illustrationsColumnConfiguration = [GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0),
                                            GridItem(.flexible(), spacing: 2.0)]

    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle") var style: ViewStyle

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20.0) {
                albumsSection()
                illustrationsSection()
            }
            .padding([.top], 20.0)
        }
        .background(Color.init(uiColor: .systemGroupedBackground))
        .onAppear {
            refreshData()
        }
        .refreshable {
            withAnimation(.snappy.speed(2)) {
                refreshData()
            }
        }
        .sheet(isPresented: $isAddingAlbum, onDismiss: {
            refreshAlbums()
        }, content: {
            NewAlbumView(albumToAddTo: currentAlbum)
        })
        .sheet(item: $albumToRename, onDismiss: {
            refreshAlbums()
        }, content: { album in
            RenameAlbumView(album: album)
        })
        .navigationTitle(currentAlbum?.name ?? String(localized: "ViewTitle.Collection"))
    }

    // MARK: Albums

    @ViewBuilder
    func albumsSection() -> some View {
        VStack(alignment: .leading, spacing: 0.0) {
            albumsHeader()
                .padding([.leading, .trailing], 20.0)
                .padding([.bottom], 6.0)
            if !albums.isEmpty {
                Divider()
                Group {
                    switch style {
                    case .grid:
                        albumsGrid()
                            .padding(20.0)
                        Divider()
                    case .list:
                        albumsList()
                    }
                }
                .background(Color.init(uiColor: .secondarySystemGroupedBackground))
            } else {
                Divider()
                    .padding([.leading], 20.0)
                Text("Albums.NoAlbums")
                    .foregroundStyle(.secondary)
                    .padding(20.0)
            }
        }
    }

    @ViewBuilder
    func albumsHeader() -> some View {
        HStack(alignment: .center, spacing: 16.0) {
            HStack(alignment: .center, spacing: 8.0) {
                ListSectionHeader(text: "Albums.Albums")
                    .font(.title2)
                if !albums.isEmpty {
                    Text("(\(albums.count))")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                withAnimation(.snappy.speed(2)) {
                    style = style == .grid ? .list : .grid
                }
            } label: {
                switch style {
                case .grid: Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                case .list: Label("Albums.Style.List", systemImage: "list.bullet")
                }
            }
            Button {
                isAddingAlbum = true
            } label: {
                Label("Shared.Create", systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    func albumsGrid() -> some View {
        LazyVGrid(columns: albumColumnConfiguration, spacing: 20.0) {
            ForEach(albums, id: \.id) { album in
                NavigationLink(value: ViewPath.album(album: album)) {
                    VStack(alignment: .leading, spacing: 8.0) {
                        Group {
                            if let coverPhotoData = album.coverPhoto,
                               let coverPhoto = UIImage(data: coverPhotoData) {
                                Image(uiImage: coverPhoto)
                                    .resizable()
                            } else {
                                Image("Album.Generic")
                                    .resizable()
                            }
                        }
                        .dropDestination(for: IllustrationTransferable.self) { items, _ in
                            for item in items {
                                moveIllustrationToAlbum(item, to: album)
                            }
                            return true
                        }
                        .aspectRatio(1.0, contentMode: .fill)
                        .foregroundStyle(.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8.0))
                        .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(album.name)
                                .foregroundStyle(.primary)
                            Text("Albums.Detail.\(album.illustrations().count),\(album.albums().count)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .contextMenu { albumContextMenu(album) }
            }
        }
    }

    @ViewBuilder
    func albumsList() -> some View {
        LazyVStack(alignment: .leading, spacing: 0.0) {
            ForEach(albums, id: \.id) { album in
                NavigationLink(value: ViewPath.album(album: album)) {
                    HStack(alignment: .center, spacing: 16.0) {
                        Group {
                            if let coverPhotoData = album.coverPhoto,
                               let coverPhoto = UIImage(data: coverPhotoData) {
                                Image(uiImage: coverPhoto)
                                    .resizable()
                            } else {
                                Image("Album.Generic")
                                    .resizable()
                            }
                        }
                        .frame(width: 30.0, height: 30.0)
                        .clipShape(RoundedRectangle(cornerRadius: 6.0))
                        .shadow(color: .black.opacity(0.2), radius: 2.0, x: 0.0, y: 2.0)
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(album.name)
                                .foregroundStyle(.primary)
                            Text("Albums.Detail.\(album.illustrations().count),\(album.albums().count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 11.0, height: 11.0)
                            .foregroundStyle(.primary.opacity(0.25))
                            .fontWeight(.bold)
                    }
                    .padding([.leading], 20.0)
                    .contentShape(Rectangle())
                    .dropDestination(for: IllustrationTransferable.self) { items, _ in
                        for item in items {
                            moveIllustrationToAlbum(item, to: album)
                        }
                        return true
                    }
                }
                .buttonStyle(.plain)
                .padding([.top, .bottom], 6.0)
                .padding([.trailing], 20.0)
                .contextMenu { albumContextMenu(album) }
                if album == albums.last {
                    Divider()
                } else {
                    Divider()
                        .padding([.leading], 66.0)
                }
            }
        }
    }

    @ViewBuilder
    func albumContextMenu(_ album: Album) -> some View {
        Button {
            withAnimation(.snappy.speed(2)) {
                album.coverPhoto = nil
            }
        } label: {
            Label("Shared.ResetCover", systemImage: "photo")
        }
        Divider()
        Button {
            albumToRename = album
        } label: {
            Label("Shared.Rename", systemImage: "pencil")
        }
        Button(role: .destructive) {
            modelContext.delete(album)
            withAnimation(.snappy.speed(2)) {
                refreshAlbums()
            }
        } label: {
            Label("Shared.Delete", systemImage: "trash")
        }
    }

    func moveIllustrationToAlbum(_ illustration: IllustrationTransferable, to album: Album) {
        let fetchDescriptor = FetchDescriptor<Illustration>(
            predicate: #Predicate<Illustration> { $0.id == illustration.id }
        )
        if let illustrations = try? modelContext.fetch(fetchDescriptor) {
            album.addChildIllustrations(illustrations)
            withAnimation(.snappy.speed(2)) {
                for illustration in illustrations {
                    self.illustrations.removeAll(where: { $0.id == illustration.id })
                }
            }
        }
    }

    // MARK: Illustrations

    @ViewBuilder
    func illustrationsSection() -> some View {
        VStack(alignment: .leading, spacing: 0.0) {
            illustrationsHeader()
            .padding([.leading, .trailing], 20.0)
            .padding([.bottom], 6.0)
            Group {
                if !illustrations.isEmpty {
                    Divider()
                    LazyVGrid(columns: illustrationsColumnConfiguration, spacing: 2.0) {
                        ForEach(illustrations, id: \.id) { illustration in
                            illustrationItem(illustration)
                        }
                    }
                    .background(Color.init(uiColor: .secondarySystemGroupedBackground))
                    Divider()
                } else {
                    Divider()
                        .padding([.leading], 20.0)
                    Text("Albums.NoIllustrations")
                        .foregroundStyle(.secondary)
                        .padding(20.0)
                }
            }
        }
    }

    @ViewBuilder
    func illustrationsHeader() -> some View {
        HStack(alignment: .center, spacing: 16.0) {
            HStack(alignment: .center, spacing: 8.0) {
                ListSectionHeader(text: "Albums.Illustrations")
                    .font(.title2)
                if !illustrations.isEmpty {
                    Text("(\(illustrations.count))")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Group {
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
                    if isSelectingIllustrations {
                        Label("Shared.Select", systemImage: "checkmark.circle.fill")
                    } else {
                        Label("Shared.Select", systemImage: "checkmark.circle")
                    }
                }
            }
            .disabled(illustrations.isEmpty)
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
                illustrationContextMenu(illustration)
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
    func illustrationLabel(_ illustration: Illustration) -> some View {
        var shouldDisplay: Bool = true
        ZStack {
            if shouldDisplay {
                Text(verbatim: "true")
                if let thumbnailImage = illustration.thumbnail() {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                } else {
                    Rectangle()
                        .foregroundStyle(.clear)
                        .overlay {
                            Image(systemName: "xmark.octagon.fill")
                                .symbolRenderingMode(.hierarchical)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28.0, height: 28.0)
                                .tint(.secondary)
                        }
                }
            } else {
                Text(verbatim: "false")
                Rectangle()
                    .foregroundStyle(.clear)
            }
        }
        .aspectRatio(1.0, contentMode: .fill)
        .onAppear {
            shouldDisplay = true
        }
        .onDisappear {
            shouldDisplay = false
        }
        .transition(.opacity.animation(.snappy.speed(2)))
    }

    @ViewBuilder
    func selectionOverlay() -> some View {
        Rectangle()
            .foregroundStyle(.black)
            .opacity(0.5)
            .overlay {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32.0, height: 32.0)
                    .foregroundStyle(.white)
            }
            .transition(.scale.animation(.snappy.speed(4)))
    }

    @ViewBuilder
    func illustrationContextMenu(_ illustration: Illustration) -> some View {
        if isSelectingIllustrations {
            if selectedIllustrations.contains(where: { $0.id == illustration.id }) {
                moveToAlbumMenu(selectedIllustrations) {
                    try? modelContext.save()
                    isSelectingIllustrations = false
                    selectedIllustrations.removeAll()
                    withAnimation(.snappy.speed(2)) {
                        refreshIllustrations()
                    }
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
            moveToAlbumMenu([illustration]) {
                try? modelContext.save()
                isSelectingIllustrations = false
                selectedIllustrations.removeAll()
                withAnimation(.snappy.speed(2)) {
                    refreshIllustrations()
                }
            }
            Divider()
            if let currentAlbum = currentAlbum, let image = illustration.image() {
                Button {
                    currentAlbum.coverPhoto = Album.makeCover(image.pngData())
                } label: {
                    Label("Shared.SetAsCover", systemImage: "photo")
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
                withAnimation(.snappy.speed(2)) {
                    refreshIllustrations()
                }
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
                    parentAlbum.addChildIllustrations(illustrations)
                    postMoveAction()
                } label: {
                    Label("Shared.MoveOutTo.\(parentAlbum.name)", systemImage: "tray.and.arrow.up")
                }
            }
            Button {
                illustrations.forEach { illustration in
                    illustration.removeFromAlbum()
                }
                postMoveAction()
            } label: {
                Label("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up")
            }
        }
        Menu {
            ForEach(albumsThatIllustrationsCanBeMovedTo()) { album in
                Button {
                    album.addChildIllustrations(illustrations)
                    postMoveAction()
                } label: {
                    Text(album.name)
                }
            }
        } label: {
            Label("Shared.AddToAlbum", systemImage: "tray.and.arrow.down")
        }
    }

    // MARK: Data

    func albumsThatIllustrationsCanBeMovedTo() -> [Album] {
        if let currentAlbum = currentAlbum {
            return currentAlbum.albums()
        } else {
            do {
                return try modelContext.fetch(FetchDescriptor<Album>(
                    predicate: #Predicate { $0.parentAlbum == nil },
                    sortBy: [SortDescriptor(\.name)]))
            } catch {
                debugPrint(error.localizedDescription)
                return []
            }
        }
    }

    func refreshData() {
        refreshAlbums()
        refreshIllustrations()
    }

    func refreshAlbums() {
        do {
            let currentAlbumID = currentAlbum?.id
            albums = try modelContext.fetch(FetchDescriptor<Album>(
                predicate: #Predicate { $0.parentAlbum?.id == currentAlbumID },
                sortBy: [SortDescriptor(\.name)]))
        } catch {
            debugPrint(error.localizedDescription)
        }
    }

    func refreshIllustrations() {
        do {
            let currentAlbumID = currentAlbum?.id
            illustrations = try modelContext.fetch(FetchDescriptor<Illustration>(
                predicate: #Predicate { $0.containingAlbum?.id == currentAlbumID },
                sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]))
        } catch {
            debugPrint(error.localizedDescription)
        }
    }

}
// swiftlint:enable type_body_length function_body_length file_length
