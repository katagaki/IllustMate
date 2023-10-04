//
//  AlbumView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftUI
import SwiftData

struct AlbumView: View {

    @Environment(\.modelContext) var modelContext

    @State var albums: [Album] = []
    @State var illustrations: [Illustration] = []
    @State var currentAlbum: Album?

    @State var isAddingAlbum: Bool = false
    @State var albumToRename: Album?

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20.0) {
                AlbumsSection(albums: $albums,
                              currentAlbum: $currentAlbum,
                              isAddingAlbum: $isAddingAlbum,
                              albumToRename: $albumToRename)
                IllustrationsSection(illustrations: $illustrations,
                                     currentAlbum: $currentAlbum)
            }
            .padding([.top], 20.0)
        }
        .onAppear {
            refreshData()
        }
        .refreshable {
            withAnimation(.snappy.speed(2)) {
                refreshData()
            }
        }
        .sheet(isPresented: $isAddingAlbum) {
            NewAlbumView(albumToAddTo: currentAlbum)
        }
        .sheet(item: $albumToRename) { album in
            RenameAlbumView(album: album)
        }
        .navigationTitle(currentAlbum?.name ?? String(localized: "ViewTitle.Collection"))
    }

    @MainActor
    func refreshData() {
        do {
            let currentAlbumID = currentAlbum?.id
            albums = try modelContext.fetch(FetchDescriptor<Album>(
                predicate: #Predicate { $0.parentAlbum?.id == currentAlbumID },
                sortBy: [SortDescriptor(\.name)]))
            illustrations = try modelContext.fetch(FetchDescriptor<Illustration>(
                predicate: #Predicate { $0.containingAlbum?.id == currentAlbumID },
                sortBy: [SortDescriptor(\.dateAdded)]))
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
}
