//
//  CollectionView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import SwiftUI

struct CollectionView: View {

    @EnvironmentObject var navigation: NavigationManager
    @Environment(ViewerManager.self) var viewer

    @State var isMoreViewPresenting: Bool = false

    var body: some View {
        NavigationStack(path: $navigation.collectionTabPath) {
            AlbumView()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isMoreViewPresenting = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $isMoreViewPresenting) {
                    MoreView()
                        .presentationDetents([.medium, .large])
                }
                .navigationDestination(for: ViewPath.self, destination: { viewPath in
                  switch viewPath {
                  case .album(let album):
                      AlbumView(currentAlbum: album)
                  case .picViewer(let namespace):
                      if let displayedPic = viewer.displayedPic {
                          if #available(iOS 18, *) {
                              PicViewer(pic: displayedPic)
                              .navigationTransition(.zoom(sourceID: viewer.displayedPicID,
                                                          in: namespace))
                          } else {
                              PicViewer(pic: displayedPic)
                          }
                      }
                  default: Color.clear
                  }
                })
        }
    }
}
