//
//  AlbumView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftData
import SwiftUI

// swiftlint:disable type_body_length
struct AlbumView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var navigationManager: NavigationManager

    var illustrationTransitionNamespace: Namespace.ID
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
    @Binding var displayedIllustration: Illustration?
    @Binding var illustrationDisplayOffset: CGSize
    @AppStorage(wrappedValue: false, "DebugShowIllustrationIDs") var showIllustrationIDs: Bool

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
                .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
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
                            Divider()
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
                    Button {
                        startOrStopSelectingIllustrations()
                    } label: {
                        Label("Shared.Select",
                              systemImage: isSelectingIllustrations ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .disabled(illustrations.isEmpty)
                }
                .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
                if !isDataLoadedFromInitialAppearance {
                    Divider()
                        .padding([.leading], 20.0)
                    ProgressView()
                        .padding(20.0)
                } else {
                    if !illustrations.isEmpty {
                        Divider()
                        if showIllustrationIDs {
                            VStack(alignment: .leading, spacing: 0.0) {
                                ForEach(illustrations, id: \.id) { illustration in
                                    Text(illustration.id)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding([.leading, .trailing], 20.0)
                                }
                                Divider()
                            }
                            .padding([.top, .bottom], 8.0)
                        }
                        IllustrationsGrid(namespace: illustrationTransitionNamespace,
                                          illustrations: $illustrations,
                                          isSelecting: $isSelectingIllustrations) { illustration in
                            illustration.id == displayedIllustration?.id
                        } isSelected: { illustration in
                            selectedIllustrations.contains(illustration)
                        } onSelect: { illustration in
                            selectOrDeselectIllustration(illustration)
                        } selectedCount: {
                            selectedIllustrations.count
                        } onDelete: { illustration in
                            if isSelectingIllustrations {
                                for illustration in selectedIllustrations {
                                    illustration.prepareForDeletion()
                                    modelContext.delete(illustration)
                                }
                            } else {
                                illustration.prepareForDeletion()
                                modelContext.delete(illustration)
                            }
                            withAnimation(.snappy.speed(2)) {
                                refreshIllustrations()
                            }
                        } moveMenu: { illustration in
                            if isSelectingIllustrations {
                                IllustrationMoveMenu(illustrations: selectedIllustrations,
                                                     containingAlbum: currentAlbum) {
                                    refreshDataAfterIllustrationMovedToAlbum()
                                }
                            } else {
                                IllustrationMoveMenu(illustrations: [illustration],
                                                     containingAlbum: currentAlbum) {
                                    refreshDataAfterIllustrationMovedToAlbum()
                                }
                            }
                        }
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Shared.Refresh") {
                    withAnimation(.snappy.speed(2)) {
                        refreshData()
                    }
                }
            }
        }
#endif
        .safeAreaInset(edge: .bottom) {
            if isSelectingIllustrations {
                SelectionBar(illustrations: $illustrations, selectedIllustrations: $selectedIllustrations) {
                    startOrStopSelectingIllustrations()
                } menuItems: {
                    Menu("Shared.Move", systemImage: "tray.full") {
                        IllustrationMoveMenu(illustrations: selectedIllustrations, containingAlbum: currentAlbum) {
                            refreshDataAfterIllustrationMovedToAlbum()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingAlbum, onDismiss: {
            withAnimation(.snappy.speed(2)) {
                refreshAlbums()
            }
        }, content: {
            NewAlbumView(albumToAddTo: currentAlbum)
        })
        .sheet(item: $albumToRename, onDismiss: {
            withAnimation(.snappy.speed(2)) {
                refreshAlbums()
            }
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
            } else {
                styleState = style
                refreshData()
            }
        }
        .onChange(of: styleState) { _, newValue in
            style = newValue
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                refreshData()
            }
        }
        .navigationTitle(currentAlbum?.name ?? String(localized: "ViewTitle.Collection"))
    }

    func deleteAlbum(_ album: Album) {
        modelContext.delete(album)
        withAnimation(.snappy.speed(2)) {
            refreshData()
        }
    }

    func startOrStopSelectingIllustrations() {
        withAnimation(.snappy.speed(2)) {
            if isSelectingIllustrations {
                selectedIllustrations.removeAll()
            }
            isSelectingIllustrations.toggle()
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

    func refreshDataAfterIllustrationMovedToAlbum() {
        selectedIllustrations.removeAll()
        withAnimation(.snappy.speed(2)) {
            refreshIllustrations()
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
// swiftlint:enable type_body_length
