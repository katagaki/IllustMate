//
//  SearchView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import SwiftData
import SwiftUI

struct SearchView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Query var albums: [Album]
    @Query var illustrations: [Illustration]
    @State var searchTerm: String = ""

    var body: some View {
        NavigationStack(path: $navigationManager.searchTabPath) {
            List {
                Section {
                    ForEach(albums.filter({ $0.name.lowercased()
                        .contains(searchTerm.lowercased().trimmingCharacters(in: .whitespaces))})) { album in
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
                                VStack(alignment: .leading, spacing: 2.0) {
                                    Text(album.name)
                                        .font(.body)
                                    Text("\(album.illustrations().count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                    }
                } header: {
                    ListSectionHeader(text: "Shared.Albums")
                        .font(.body)
                }
                Section {
                    ForEach(illustrations.filter({ $0.name.lowercased()
                        .contains(searchTerm.lowercased().trimmingCharacters(in: .whitespaces))})) { illustration in
                            if let uiImage = UIImage(data: illustration.thumbnail) {
                                HStack(alignment: .center, spacing: 16.0) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                    .frame(width: 30.0, height: 30.0)
                                    .clipShape(RoundedRectangle(cornerRadius: 6.0))
                                    Text(illustration.name)
                                        .font(.body)
                                    Spacer()
                                }
                            }
                    }
                } header: {
                    ListSectionHeader(text: "Shared.Illustrations")
                        .font(.body)
                }
            }
            .searchable(text: $searchTerm)
            .navigationTitle("ViewTitle.Search")
        }
    }
}
