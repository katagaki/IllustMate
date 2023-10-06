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
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var navigationManager: NavigationManager

    @Namespace var illustrationTransitionNamespace
    @Namespace var albumTransitionNamespace

    @State var albums: [Album] = []
    @State var illustrations: [Illustration] = []
    @State var currentAlbum: Album?

    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle") var style: ViewStyle
    @State var styleState: ViewStyle = .grid
    // HACK: To get animations working as @AppStorage does not support animations

    @State var isAddingAlbum: Bool = false
    @State var albumToRename: Album?

    @State var isSelectingIllustrations: Bool = false
    @State var selectedIllustrations: [Illustration] = []

    @State var displayedIllustration: Illustration?
    @State var illustrationDisplayOffset: CGSize = .zero

    let albumColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 20.0)]
    let illustrationsColumnConfiguration = [GridItem(.adaptive(minimum: 80.0), spacing: 2.0)]

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
                CollectionHeader(title: "Albums.Albums", count: albums.count) {
                    Button {
                        withAnimation(.snappy.speed(2)) {
                            styleState = styleState == .grid ? .list : .grid
                        }
                    } label: {
                        switch style {
                        case .grid: Label("Albums.Style.Grid", systemImage: "square.grid.2x2")
                        case .list: Label("Albums.Style.List", systemImage: "list.bullet")
                        }
                    }
                    Button("Shared.Create", systemImage: "plus") {
                        isAddingAlbum = true
                    }
                }
                .padding([.leading, .trailing], 20.0)
                .padding([.bottom], 6.0)
                if !albums.isEmpty {
                    Divider()
                        .padding([.leading], colorScheme == .light ? 0.0 : 20.0)
                    switch styleState {
                    case .grid:
                        LazyVGrid(columns: albumColumnConfiguration, spacing: 20.0) {
                            ForEach(albums) { album in
                                NavigationLink(value: ViewPath.album(album: album)) {
                                    AlbumGridLabel(namespace: albumTransitionNamespace,
                                                   id: album.id, image: album.cover(), title: album.name,
                                                   numberOfIllustrations: album.illustrations().count,
                                                   numberOfAlbums: album.albums().count)
                                    .dropDestination(for: IllustrationTransferable.self) { items, _ in
                                        for item in items {
                                            moveIllustrationToAlbum(item, to: album)
                                        }
                                        return true
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu { albumContextMenu(album) }
                            }
                        }
                        .padding(20.0)
                        .background(colorScheme == .light ?
                                    Color.init(uiColor: .secondarySystemGroupedBackground) :
                                        Color.init(uiColor: .systemBackground))
                        if colorScheme == .light {
                            Divider()
                        }
                    case .list:
                        LazyVStack(alignment: .leading, spacing: 0.0) {
                            ForEach(albums, id: \.id) { album in
                                NavigationLink(value: ViewPath.album(album: album)) {
                                    AlbumListRow(namespace: albumTransitionNamespace,
                                                 id: album.id, image: album.cover(), title: album.name,
                                                 numberOfIllustrations: album.illustrations().count,
                                                 numberOfAlbums: album.albums().count)
                                    .dropDestination(for: IllustrationTransferable.self) { items, _ in
                                        for item in items {
                                            moveIllustrationToAlbum(item, to: album)
                                        }
                                        return true
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu { albumContextMenu(album) }
                                if album == albums.last {
                                    Divider()
                                } else {
                                    Divider()
                                        .padding([.leading], 84.0)
                                }
                            }
                        }
                        .background(colorScheme == .light ?
                                    Color.init(uiColor: .secondarySystemGroupedBackground) :
                                        Color.init(uiColor: .systemBackground))
                    }
                } else {
                    Divider()
                        .padding([.leading], 20.0)
                    Text("Albums.NoAlbums")
                        .foregroundStyle(.secondary)
                        .padding(20.0)
                }
                Spacer(minLength: 20.0)
                CollectionHeader(title: "Albums.Illustrations", count: illustrations.count) {
                    Group {
                        Button {
                            withAnimation(.snappy.speed(2)) {
                                if isSelectingIllustrations {
                                    selectedIllustrations.removeAll()
                                }
                                isSelectingIllustrations.toggle()
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
                .padding([.leading, .trailing], 20.0)
                .padding([.bottom], 6.0)
                if !illustrations.isEmpty {
                    Divider()
                    LazyVGrid(columns: illustrationsColumnConfiguration, spacing: 2.0) {
                        ForEach(illustrations, id: \.id) { illustration in
                            // TODO: Refactor again when the cause of the freeze has been resolved
                            // IllustrationLabel(illustrationPath: illustration.thumbnailPath())
                            let thumbnailImage = UIImage(contentsOfFile: illustration.thumbnailPath())
                            var shouldDisplay: Bool = true
                            ZStack(alignment: .center) {
                                if shouldDisplay {
                                    if let thumbnailImage = thumbnailImage {
                                        Image(uiImage: thumbnailImage)
                                            .resizable()
                                    } else {
                                        Image(systemName: "xmark.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 24.0, height: 24.0)
                                            .foregroundStyle(.primary)
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                } else {
                                    Rectangle()
                                        .foregroundStyle(.clear)
                                }
                            }
                            .matchedGeometryEffect(id: illustration.id, in: illustrationTransitionNamespace)
                            .aspectRatio(1.0, contentMode: .fill)
                            .transition(.opacity.animation(.snappy.speed(2)))
                            .contentShape(Rectangle())
                            .onAppear {
                                shouldDisplay = true
                            }
                            .onDisappear {
                                shouldDisplay = false
                            }
                            .overlay {
                                if selectedIllustrations.contains(illustration) {
                                    SelectionOverlay()
                                }
                            }
                            .onTapGesture {
                                selectOrDeselectIllustration(illustration)
                            }
                            .contextMenu {
                                illustrationContextMenu(illustration)
                            } preview: {
                                if let image = UIImage(contentsOfFile: illustration.illustrationPath()) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                }
                            }
                            .draggable(IllustrationTransferable(id: illustration.id)) {
                                if let thumbnailImage = thumbnailImage {
                                    // IllustrationLabel(illustrationPath: illustration.thumbnailPath())
                                    Image(uiImage: thumbnailImage)
                                        .resizable()
                                        .frame(width: 100.0, height: 100.0)
                                        .clipShape(RoundedRectangle(cornerRadius: 8.0))
                                }
                            }
                        }
                    }
                    .background(colorScheme == .light ?
                                Color.init(uiColor: .secondarySystemGroupedBackground) :
                                    Color.init(uiColor: .systemBackground))
                    if colorScheme == .light {
                        Divider()
                    }
                } else {
                    Divider()
                        .padding([.leading], 20.0)
                    Text("Albums.NoIllustrations")
                        .foregroundStyle(.secondary)
                        .padding(20.0)
                }
            }
            .padding([.top], 20.0)
        }
        .background(Color.init(uiColor: .systemGroupedBackground))
#if !targetEnvironment(macCatalyst)
        .refreshable {
            withAnimation(.snappy.speed(2)) {
                refreshData()
            }
        }
#else
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy.speed(2)) {
                        refreshData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
#endif
        .overlay {
            if let displayedIllustration = displayedIllustration {
                IllustrationViewer(namespace: illustrationTransitionNamespace,
                                   displayedIllustration: displayedIllustration,
                                   illustrationDisplayOffset: $illustrationDisplayOffset) {
                    withAnimation(.snappy.speed(2)) {
                        self.displayedIllustration = nil
                        illustrationDisplayOffset = .zero
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectingIllustrations {
                SelectionBar(illustrations: $illustrations,
                             selectedIllustrations: $selectedIllustrations) {
                    Menu("Shared.Move", systemImage: "tray.full") {
                        moveToAlbumMenu(selectedIllustrations) {
                            try? modelContext.save()
                            isSelectingIllustrations = false
                            selectedIllustrations.removeAll()
                            withAnimation(.snappy.speed(2)) {
                                refreshIllustrations()
                            }
                        }
                    }
                    .transition(.opacity.animation(.snappy.speed(2)))
                }
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
        .onAppear {
            styleState = style
            refreshData()
        }
        .onChange(of: styleState, { _, newValue in
            style = newValue
        })
        .navigationTitle(currentAlbum?.name ?? String(localized: "ViewTitle.Collection"))
    }

    // MARK: Albums

    @ViewBuilder
    func albumContextMenu(_ album: Album) -> some View {
        Button("Shared.ResetCover", systemImage: "photo") {
            withAnimation(.snappy.speed(2)) {
                album.coverPhoto = nil
            }
        }
        Divider()
        Button("Shared.Rename", systemImage: "pencil") {
            albumToRename = album
        }
        Button("Shared.Delete", systemImage: "trash", role: .destructive) {
            modelContext.delete(album)
            withAnimation(.snappy.speed(2)) {
                refreshAlbums()
            }
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
    func illustrationContextMenu(_ illustration: Illustration) -> some View {
        if isSelectingIllustrations {
            if selectedIllustrations.contains(where: { $0.id == illustration.id }) {
                Text("Shared.Selected.\(selectedIllustrations.count)")
                Divider()
                moveToAlbumMenu(selectedIllustrations) {
                    try? modelContext.save()
                    isSelectingIllustrations = false
                    selectedIllustrations.removeAll()
                    withAnimation(.snappy.speed(2)) {
                        refreshIllustrations()
                    }
                }
                Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                    for illustration in selectedIllustrations {
                        illustration.prepareForDeletion()
                        modelContext.delete(illustration)
                    }
                    withAnimation(.snappy.speed(2)) {
                        refreshIllustrations()
                    }
                }
            }
        } else {
            Button("Shared.Select", systemImage: "checkmark.circle") {
                withAnimation(.snappy.speed(2)) {
                    isSelectingIllustrations = true
                    selectedIllustrations.append(illustration)
                }
            }
            Divider()
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
            if let currentAlbum = currentAlbum {
                Button("Shared.SetAsCover", systemImage: "photo") {
                    let image = UIImage(contentsOfFile: illustration.illustrationPath())
                    if let data = image?.jpegData(compressionQuality: 1.0) {
                        currentAlbum.coverPhoto = Album.makeCover(data)
                    }
                }
            }
            moveToAlbumMenu([illustration]) {
                try? modelContext.save()
                isSelectingIllustrations = false
                selectedIllustrations.removeAll()
                withAnimation(.snappy.speed(2)) {
                    refreshIllustrations()
                }
            }
            Divider()
            Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                illustration.prepareForDeletion()
                modelContext.delete(illustration)
                withAnimation(.snappy.speed(2)) {
                    refreshIllustrations()
                }
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
                    Label(
                        title: { Text("Shared.MoveOutTo.\(parentAlbum.name)") },
                        icon: { Image(uiImage: parentAlbum.cover()) }
                    )
                }
            }
            Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                illustrations.forEach { illustration in
                    illustration.removeFromAlbum()
                }
                postMoveAction()
            }
        }
        Menu("Shared.AddToAlbum", systemImage: "tray.and.arrow.down") {
            ForEach(albumsThatIllustrationsCanBeMovedTo()) { album in
                Button {
                    album.addChildIllustrations(illustrations)
                    postMoveAction()
                } label: {
                    Label(
                        title: { Text(album.name) },
                        icon: { Image(uiImage: album.cover()) }
                    )
                }
            }
        }
    }

    func selectOrDeselectIllustration(_ illustration: Illustration) {
        if isSelectingIllustrations {
            if selectedIllustrations.contains(where: { $0.id == illustration.id }) {
                selectedIllustrations.removeAll(where: { $0.id == illustration.id })
            } else {
                selectedIllustrations.append(illustration)
            }
        } else {
            withAnimation(.snappy.speed(2)) {
                displayedIllustration = illustration
            }
        }
    }

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
