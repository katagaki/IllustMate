//
//  CollectionView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import SwiftUI
import SwiftData

struct CollectionView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(ViewerManager.self) var viewer

    @State var isMoreViewPresenting: Bool = false

    var body: some View {
        NavigationStack(path: $navigationManager.collectionTabPath) {
            AlbumView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isMoreViewPresenting = true
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                        }
                    }
                }
                .sheet(isPresented: $isMoreViewPresenting) {
                    MoreView()
                }
                .navigationDestination(for: ViewPath.self, destination: { viewPath in
                  switch viewPath {
                  case .album(let album):
                      AlbumView(currentAlbum: album)
                  case .illustrationViewer(let namespace):
                      if let displayedIllustration = viewer.displayedIllustration,
                         let displayedImage = viewer.displayedImage {
                          if #available(iOS 18, *) {
                              IllustrationViewer(illustration: displayedIllustration,
                                                 displayedImage: displayedImage)
                              .navigationTransition(.zoom(sourceID: viewer.displayedIllustrationID,
                                                          in: namespace))
                          } else {
                              IllustrationViewer(illustration: displayedIllustration,
                                                 displayedImage: displayedImage)
                          }
                      }
                  default: Color.clear
                  }
                })
        }
    }
}
