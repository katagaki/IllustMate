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
    var albums: [Album]

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
                    AlbumsSection(albums: .constant(albums), style: .constant(.grid),
                                  enablesContextMenu: false) { _ in }
                }
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
