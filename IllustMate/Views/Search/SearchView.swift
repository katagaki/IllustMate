//
//  SearchView.swift
//  PicMate
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
                if searchTerm.trimmingCharacters(in: .whitespaces) != "" {
                    if !albumsFound().isEmpty {
                        Section {
                            ForEach(albumsFound()) { album in
                                AlbumRow(album: album)
                            }
                        } header: {
                            ListSectionHeader(text: "Shared.Albums")
                                .font(.body)
                        }
                    }
                    if !illustrationsFound().isEmpty {
                        Section {
                            ForEach(illustrationsFound()) { illustration in
                                Text(illustration.name)
                                    .font(.body)
                            }
                        } header: {
                            ListSectionHeader(text: "Shared.Illustrations")
                                .font(.body)
                        }
                    }
                }
            }
            .searchable(text: $searchTerm)
            .navigationTitle("ViewTitle.Search")
        }
    }

    func albumsFound() -> [Album] {
        albums.filter({ $0.name.lowercased()
            .contains(searchTerm.lowercased().trimmingCharacters(in: .whitespaces))})
    }

    func illustrationsFound() -> [Illustration] {
        illustrations.filter({ $0.name.lowercased()
            .contains(searchTerm.lowercased().trimmingCharacters(in: .whitespaces))})
    }
}
