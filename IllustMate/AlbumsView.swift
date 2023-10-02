//
//  AlbumsView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import SwiftUI
import SwiftData

struct AlbumsView: View {

    @Environment(\.modelContext) var modelContext
    @Query(sort: \Album.name, order: .forward, animation: .snappy.speed(2)) var albums: [Album]

    let columnConfiguration = [GridItem(.flexible(), spacing: 20.0),
                               GridItem(.flexible(), spacing: 20.0)]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVGrid(columns: columnConfiguration, spacing: 20.0) {
                    ForEach(albums) { album in
                        NavigationLink {
                            AlbumView()
                        } label: {
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
                                .aspectRatio(1.0, contentMode: .fill)
                                .foregroundStyle(.accent)
                                .background(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8.0))
                                .shadow(color: .black.opacity(0.2), radius: 4.0, x: 0.0, y: 4.0)
                                VStack(alignment: .leading, spacing: 2.0) {
                                    Text(album.name)
                                        .tint(.primary)
                                    Text(String(album.illustrations.count))
                                        .tint(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(20.0)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        modelContext.insert(Album(name: Date.now.formatted(), dateCreated: .now))
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationTitle("Albums")
        }
    }
}
