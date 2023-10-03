//
//  SearchView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import SwiftUI

struct SearchView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @State var searchTerm: String = ""

    var body: some View {
        NavigationStack(path: $navigationManager.searchTabPath) {
            List {
                
            }
            .searchable(text: $searchTerm)
            .navigationTitle("ViewTitle.Search")
        }
    }
}
