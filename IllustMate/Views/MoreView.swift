//
//  MoreView.swift
//  IllustMate
//
//  Created by シン・ジャスティン on 2023/10/02.
//

import Komponents
import SwiftData
import SwiftUI

struct MoreView: View {

    @Environment(\.modelContext) var modelContext
    @Query var albums: [Album]
    @Query var illustrations: [Illustration]

    var body: some View {
        NavigationStack {
            MoreList(repoName: "katagaki/IllustMate") {
                Section {
                    Button {
                        for album in albums {
                            modelContext.delete(album)
                        }
                        for illustration in illustrations {
                            modelContext.delete(illustration)
                        }
                    } label: {
                        Text("More.DeleteAll")
                    }
                }
            }
        }
    }
}
