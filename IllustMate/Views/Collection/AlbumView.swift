//
//  AlbumView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftData
import SwiftUI

struct AlbumView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @Environment(ConcurrencyManager.self) var concurrency
    @EnvironmentObject var navigationManager: NavigationManager

    var namespace: Namespace.ID

    @State var isDataLoadedFromInitialAppearance: Bool = false

    var currentAlbum: Album?
    @State var albums: [Album]?
    @State var isConfirmingDeleteAlbum: Bool = false
    @State var albumPendingDeletion: Album?
    @State var isAddingAlbum: Bool = false
    @State var albumToRename: Album?
    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle", store: defaults) var style: ViewStyle
    @State var styleState: ViewStyle = .grid
    // HACK: To get animations working as @AppStorage does not support animations

    @State var illustrations: [Illustration]?
    @State var isConfirmingDeleteIllustration: Bool = false
    @State var isConfirmingDeleteSelectedIllustrations: Bool = false
    @State var illustrationPendingDeletion: Illustration?
    @State var isSelectingIllustrations: Bool = false
    @State var selectedIllustrations: [Illustration] = []
    @Binding var viewerManager: ViewerManager
    @AppStorage(wrappedValue: false, "IllustrationSortReversed") var isIllustrationSortReversed: Bool

    let actor = DataActor(modelContainer: sharedModelContainer)
    @AppStorage(wrappedValue: true, "DebugThreadSafety") var useThreadSafeLoading: Bool

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
                CollectionHeader(title: "Albums.Albums", count: albums?.count ?? 0) {
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
                if let albums {
                    if !albums.isEmpty {
                        Divider()
                            .padding([.leading], colorScheme == .light ? 0.0 : 20.0)
                        AlbumsSection(albums: albums, style: $styleState) { album in
                            albumToRename = album
                        } onDelete: { album in
                            deleteAlbum(album)
                        } onDrop: { transferable, album in
                            moveDropToAlbum(transferable, to: album)
                        } moveMenu: { album in
                            AlbumMoveMenu(album: album) {
                                refreshDataAfterAlbumMoved()
                            }
                        }
                        if colorScheme == .light || styleState == .list {
                            Divider()
                        }
                    } else {
                        Divider()
                            .padding([.leading], 20.0)
                        Text("Albums.NoAlbums")
                            .foregroundStyle(.secondary)
                            .padding(20.0)
                    }
                } else {
                    Divider()
                        .padding([.leading], 20.0)
                    ProgressView()
                        .padding(20.0)
                }
                Spacer()
                    .frame(height: 20.0)
                CollectionHeader(title: "Albums.Illustrations", count: illustrations?.count ?? 0) {
                    Button {
                        isIllustrationSortReversed.toggle()
                        withAnimation(.snappy.speed(2)) {
                            refreshIllustrations()
                        }
                    } label: {
                        Label("Shared.Sort", systemImage: isIllustrationSortReversed ? "arrow.down" : "arrow.up")
                    }
                    Button {
                        startOrStopSelectingIllustrations()
                    } label: {
                        Label("Shared.Select",
                              systemImage: isSelectingIllustrations ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .disabled(illustrations == nil || (illustrations?.isEmpty ?? true))
                }
                .padding(EdgeInsets(top: 0.0, leading: 20.0, bottom: 6.0, trailing: 20.0))
                if let illustrations {
                    if !illustrations.isEmpty {
                        Divider()
                        IllustrationsGrid(namespace: namespace, illustrations: illustrations,
                                          isSelecting: $isSelectingIllustrations) { illustration in
                            illustration.id == viewerManager.displayedIllustration?.id
                        } isSelected: { illustration in
                            selectedIllustrations.contains(illustration)
                        } onSelect: { illustration in
                            selectOrDeselectIllustration(illustration)
                        } selectedCount: {
                            selectedIllustrations.count
                        } onDelete: { illustration in
                            deleteIllustration(illustration)
                        } moveMenu: { illustration in
                            IllustrationMoveMenu(illustrations: isSelectingIllustrations ?
                                                 selectedIllustrations : [illustration],
                                                 containingAlbum: currentAlbum) {
                                refreshDataAfterIllustrationMoved()
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
                } else {
                    Divider()
                        .padding([.leading], 20.0)
                    ProgressView()
                        .padding(20.0)
                }
                HStack(alignment: .center, spacing: 8.0) {
                    Spacer()
                    NavigationLink(value: ViewPath.importer(selectedAlbum: currentAlbum)) {
                        Label("Shared.Import", systemImage: "square.and.arrow.down.on.square")
                    }
                }
                .padding([.top, .bottom], 8.0)
                .padding([.leading, .trailing], 20.0)
            }
            .padding([.top], 20.0)
        }
        .background(Color.init(uiColor: .systemGroupedBackground))
#if targetEnvironment(macCatalyst)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Shared.Refresh") {
                    withAnimation(.snappy.speed(2)) {
                        refreshData()
                    }
                }
            }
        }
#else
        .refreshable {
            withAnimation(.snappy.speed(2)) {
                refreshData()
            }
        }
#endif
        .safeAreaInset(edge: .bottom) {
            if isSelectingIllustrations, let illustrations {
                SelectionBar(illustrations: illustrations, selectedIllustrations: $selectedIllustrations) {
                    startOrStopSelectingIllustrations()
                } menuItems: {
                    Menu("Shared.Move", systemImage: "tray.full") {
                        IllustrationMoveMenu(illustrations: selectedIllustrations, containingAlbum: currentAlbum) {
                            refreshDataAfterIllustrationMoved()
                        }
                    }
                    Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                        deleteIllustrations()
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingAlbum) {
            withAnimation(.snappy.speed(2)) {
                refreshAlbums()
            }
        } content: {
            NewAlbumView(albumToAddTo: currentAlbum)
        }
        .sheet(item: $albumToRename) {
            withAnimation(.snappy.speed(2)) {
                refreshAlbums()
            }
        } content: { album in
            RenameAlbumView(album: album)
        }
        .confirmationDialog("Shared.DeleteConfirmation.Album",
                            isPresented: $isConfirmingDeleteAlbum, titleVisibility: .visible) {
            Button("Shared.Yes", role: .destructive) {
                confirmDeleteAlbum()
            }
            Button("Shared.No", role: .cancel) {
                albumPendingDeletion = nil
            }
        }
        .confirmationDialog("Shared.DeleteConfirmation.Picture",
                            isPresented: $isConfirmingDeleteIllustration, titleVisibility: .visible) {
            Button("Shared.Yes", role: .destructive) {
                confirmDeleteIllustration()
            }
            Button("Shared.No", role: .cancel) {
                illustrationPendingDeletion = nil
            }
        }
        .confirmationDialog("Shared.DeleteConfirmation.Picture.\(selectedIllustrations.count)",
                            isPresented: $isConfirmingDeleteSelectedIllustrations, titleVisibility: .visible) {
            Button("Shared.Yes", role: .destructive) {
                confirmDeleteIllustration()
                selectedIllustrations.removeAll()
            }
            Button("Shared.No", role: .cancel) {
                illustrationPendingDeletion = nil
            }
        }
        .onAppear {
            if useThreadSafeLoading {
                if albums != nil && illustrations != nil {
                    styleState = style
                    refreshData(animated: false)
                } else {
                    styleState = style
                    refreshData()
                }
            } else {
                if isDataLoadedFromInitialAppearance {
                    concurrency.queue.addOperation {
                        styleState = style
                        refreshData()
                    }
                } else {
                    concurrency.queue.addOperation {
                        styleState = style
                        withAnimation(.snappy.speed(2)) {
                            refreshData()
                        } completion: {
                            isDataLoadedFromInitialAppearance = true
                        }
                    }
                }
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

}
