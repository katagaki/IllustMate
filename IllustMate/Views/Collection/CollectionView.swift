//
//  CollectionView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/03.
//

import Komponents
import SwiftUI

struct CollectionView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(ViewerManager.self) var viewer

    @State var isMoreViewPresenting: Bool = false

    var body: some View {
        NavigationStack(path: $navigationManager.collectionTabPath) {
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
                  case .illustrationViewer(let namespace):
                      if let displayedIllustration = viewer.displayedIllustration {
                          if #available(iOS 18, *) {
                              IllustrationViewer(illustration: displayedIllustration)
                              .navigationTransition(.zoom(sourceID: viewer.displayedIllustrationID,
                                                          in: namespace))
                          } else {
                              IllustrationViewer(illustration: displayedIllustration)
                          }
                      }
                  default: Color.clear
                  }
                })
        }
    }
}
