//
//  AlbumView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftData
import SwiftUI

// swiftlint:disable type_body_length function_body_length file_length
struct AlbumView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var navigationManager: NavigationManager

    @Namespace var illustrationTransitionNamespace
    @Namespace var albumTransitionNamespace

    var currentAlbum: Album?
    @State var albums: [Album] = []
    @State var illustrations: [Illustration] = []
    @State var isDataLoadedFromInitialAppearance: Bool = false

    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle") var style: ViewStyle
    @State var styleState: ViewStyle = .grid
    // HACK: To get animations working as @AppStorage does not support animations

    @State var isAddingAlbum: Bool = false
    @State var albumToRename: Album?

    @State var isSelectingIllustrations: Bool = false
    @State var selectedIllustrations: [Illustration] = []

    @State var displayedIllustration: Illustration?
    @State var illustrationDisplayOffset: CGSize = .zero

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
                if !isDataLoadedFromInitialAppearance {
                    Divider()
                        .padding([.leading], 20.0)
                    ProgressView()
                        .padding(20.0)
                } else {
                    if !albums.isEmpty {
                        Divider()
                            .padding([.leading], colorScheme == .light ? 0.0 : 20.0)
                        switch styleState {
                        case .grid:
                            AlbumsGrid(namespace: albumTransitionNamespace, albums: $albums) { album in
                                albumToRename = album
                            } onDelete: { album in
                                deleteAlbum(album)
                            } onDrop: { transferable, album in
                                moveIllustrationToAlbum(transferable, to: album)
                            }
                            if colorScheme == .light {
                                Divider()
                            }
                        case .list:
                            AlbumsList(namespace: albumTransitionNamespace, albums: $albums) { album in
                                albumToRename = album
                            } onDelete: { album in
                                deleteAlbum(album)
                            } onDrop: { transferable, album in
                                moveIllustrationToAlbum(transferable, to: album)
                            }

                        }
                    } else {
                        Divider()
                            .padding([.leading], 20.0)
                        Text("Albums.NoAlbums")
                            .foregroundStyle(.secondary)
                            .padding(20.0)
                    }
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
                if !isDataLoadedFromInitialAppearance {
                    Divider()
                        .padding([.leading], 20.0)
                    ProgressView()
                        .padding(20.0)
                } else {
                    if !illustrations.isEmpty {
                        Divider()
                        LazyVGrid(columns: illustrationsColumnConfiguration, spacing: 2.0) {
                            ForEach(illustrations, id: \.id) { illustration in
                                IllustrationLabel(namespace: illustrationTransitionNamespace,
                                                  illustration: illustration)
                                    .opacity(illustration.id == displayedIllustration?.id ? 0.0 : 1.0)
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
                            }
                        }
                        .background(colorScheme == .light ?
                                    Color.init(uiColor: .secondarySystemGroupedBackground) :
                                        Color.init(uiColor: .systemBackground))
                    } else {
                        Divider()
                            .padding([.leading], 20.0)
                        Text("Albums.NoIllustrations")
                            .foregroundStyle(.secondary)
                            .padding(20.0)
                    }
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
                    } completion: {
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
        .task {
            if !isDataLoadedFromInitialAppearance {
                withAnimation(.snappy.speed(2)) {
                    styleState = style
                    refreshData()
                    isDataLoadedFromInitialAppearance = true
                }
            }
        }
        .onChange(of: styleState, { _, newValue in
            style = newValue
        })
        .onChange(of: scenePhase, { _, newValue in
            if newValue == .active {
                refreshData()
            }
        })
        .navigationTitle(currentAlbum?.name ?? String(localized: "ViewTitle.Collection"))
    }

    // MARK: Albums

    func deleteAlbum(_ album: Album) {
        modelContext.delete(album)
        withAnimation(.snappy.speed(2)) {
            refreshData()
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
            Divider()
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
            Button("Shared.MoveOutOfAlbum", systemImage: "tray.and.arrow.up") {
                illustrations.forEach { illustration in
                    illustration.removeFromAlbum()
                }
                postMoveAction()
            }
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
