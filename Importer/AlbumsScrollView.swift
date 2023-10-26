//
//  AlbumsScrollView.swift
//  Importer
//
//  Created by シン・ジャスティン on 2023/10/15.
//

import Komponents
import SwiftUI

struct AlbumsScrollView: View {

    var title: LocalizedStringKey
    var parentAlbum: Album?
    @State var albums: [Album] = []

    @AppStorage(wrappedValue: ViewStyle.grid, "AlbumViewStyle", store: defaults) var style: ViewStyle
    @AppStorage(wrappedValue: SortType.nameAscending, "AlbumSort", store: defaults) var albumSort: SortType

    let actor = DataActor(modelContainer: sharedModelContainer)

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0.0) {
                Text(title)
                    .font(.title)
                    .bold()
                    .padding([.leading, .trailing], 20.0)
                    .padding([.top], 10.0)
                Divider()
                    .padding([.leading], 20.0)
                    .padding([.top], 10.0)
                if albums.count == 0 {
                    Text("Albums.NoMoreAlbums")
                        .foregroundStyle(.secondary)
                        .padding([.leading, .trailing], 20.0)
                        .padding([.top], 10.0)
                } else {
                    AlbumsSection(albums: albums, style: $style,
                                  enablesContextMenu: false) { _ in }
                }
            }
        }
        .task {
            do {
                albums = try await actor.albums(in: parentAlbum, sortedBy: albumSort)
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CloseButton {
                    close()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    func close() {
        NotificationCenter.default.post(name: NSNotification.Name("close"), object: nil)
    }
}
